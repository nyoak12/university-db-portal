from flask import Blueprint, render_template, redirect, session, request
import config
from datetime import datetime

student = Blueprint('student', __name__)

def student_required():
    return session.get('role') != 'student'

@student.route('/student')
def dashboard():
    if student_required():
        return redirect('/login')
    
    #student homepage
    return render_template('student/dashboard.html')

@student.route('/student/register', methods=['GET', 'POST'])
def register():
    if student_required():
        return redirect('/login')
    
    #student enrolls in class
    if request.method == 'POST':
        f = request.form
        db = config.get_db()
        cursor = db.cursor()
        cursor.callproc('enroll_student', [session['user_id'], f['course_id'], f['sec_id'], f['semester'], f['year']])
        db.commit()
        cursor.close(); db.close()
        return redirect(f"/student/register?semester={f['semester']}&year={f['year']}")
    
    db = config.get_db()
    cursor = db.cursor()
    
    #prepares dropdown menu for unique terms but only for the existing term or future term
    current_year = datetime.now().year
    cursor.execute("SELECT DISTINCT semester, year FROM section WHERE year >= %s ORDER BY year, semester", (current_year,))
    terms = cursor.fetchall()
    unique_semesters = sorted({term['semester'] for term in terms})
    unique_years = sorted({str(term['year']) for term in terms}, reverse=True)

    #return sections from selection
    selected_semester = request.args.get('semester')
    selected_year = request.args.get('year')
    if selected_semester and selected_year:
        cursor.callproc('get_sections_by_term', [selected_semester, selected_year])
        classes_for_registering = cursor.fetchall()
    else:
        classes_for_registering = []
    cursor.close()

    #prereq logic filter for jinja
    cursor2 = db.cursor()
    cursor2.callproc('get_eligible_courses', [session['user_id']])
    eligible = {row['course_id'] for row in cursor2.fetchall()}
    cursor2.close()

    # for when student hits enroll - gives user feedback 
    cursor3 = db.cursor()
    cursor3.execute(
        "SELECT course_id FROM takes WHERE ID=%s AND semester=%s AND year=%s",
        [session['user_id'], selected_semester, selected_year]
    )
    enrolled = {row['course_id'] for row in cursor3.fetchall()}
    cursor3.close()

    db.close()
    return render_template('student/register.html', 
                           classes_for_registering=classes_for_registering,
                           unique_semesters=unique_semesters,
                           unique_years=unique_years, 
                           selected_semester=selected_semester,
                           selected_year=selected_year,
                           eligible=eligible,
                           enrolled=enrolled)

@student.route('/student/drop', methods=['GET', 'POST'])
def drop():
    if student_required():
        return redirect('/login')

    db = config.get_db()
    cursor = db.cursor()

    # submits drop when student clicks button
    if request.method == 'POST':
        f = request.form
        cursor.callproc('drop_enrollment', [session['user_id'], f['course_id'], f['sec_id'], f['semester'], f['year']])
        db.commit()
        cursor.close(); db.close()
        return redirect(f"/student/drop?term={request.form.get('term', '')}")

    # gets classes student is enrolled in
    cursor.callproc('get_droppable_courses', [session['user_id']])
    droppable = cursor.fetchall()
    cursor.close(); db.close()

    # filters out droppable classes to be current term or future enrolled terms 
    month = datetime.now().month
    current_semester = 'Spring' if month <= 5 else ('Fall' if month >= 9 else 'Summer')
    current_year = str(datetime.now().year)
    order = {'Spring': 1, 'Summer': 2, 'Fall': 3}
    droppable = [r for r in droppable
                 if int(r['year']) > int(current_year)
                 or (str(r['year']) == current_year and order[r['semester']] >= order[current_semester])]
    
    selected_term = request.args.get('term', f"{current_semester}-{current_year}")
    sem, yr = selected_term.split('-')
    selected_courses = [r for r in droppable if r['semester'] == sem and str(r['year']) == yr]

    terms = sorted({(r['semester'], str(r['year'])) for r in droppable},
                   key=lambda t: (-int(t[1]), order[t[0]]))

    return render_template('student/drop.html', 
                           droppable=droppable,
                           terms=terms,
                           selected_term=selected_term,
                           selected_semester=sem,
                           selected_year=yr,
                           selected_courses=selected_courses)

@student.route('/student/transcript')
def transcript():
    if student_required():
        return redirect('/login')
    
    db = config.get_db()
    cursor = db.cursor()

    #reads student transcript table
    cursor.callproc('read_student_transcript', [session['user_id']])
    transcript = cursor.fetchall()
    cursor.close()
    db.close()

    #only populate completed grades , then calculate average gpa
    grade_list = [row['points'] for row in transcript if row['letter_grade'] not in ('W', 'I')]
    grade_average = sum(grade_list)/ len(grade_list) if grade_list else 0.0

    return render_template('student/transcript.html', transcript=transcript, grade_average=grade_average)

@student.route('/student/schedule')
def schedule():
    if student_required():
        return redirect('/login')
    
    db = config.get_db()
    cursor = db.cursor()

    #reads student schedule by getting everything from takes plus the class information associated
    cursor.callproc('get_student_schedule', [session['user_id']])
    schedule = cursor.fetchall()
    cursor.close()
    db.close()

    # get current term in case there is nothing in current term
    current_month = datetime.now().month
    current_year = str(datetime.now().year)
    current_semester = ''
    if current_month <= 5:
        current_semester = 'Spring'
    elif current_month >= 9:
        current_semester = 'Fall'
    else:
        current_semester = 'Summer'

    #sorts the dropdown menu to show semester + year in order
    semester_order = {'Spring': 1, 'Summer': 2, 'Fall': 3}
    selected_semester = request.args.get('semester') or current_semester
    selected_year = request.args.get('year') or current_year
    terms = {(row['semester'], str(row['year'])) for row in schedule}
    terms.add((current_semester, current_year))
    terms = sorted(terms, key=lambda t: (-int(t[1]), semester_order.get(t[0], 0)))
    selected_term = request.args.get('term') or f"{current_semester}-{current_year}"
    parts = selected_term.split('-')
    selected_semester = parts[0]
    selected_year = parts[1]

    return render_template('student/schedule.html',
                           schedule=schedule,
                           terms=terms,
                           selected_term=selected_term,
                           selected_semester=selected_semester,
                           selected_year=selected_year)

@student.route('/student/advisor')
def advisor():
    if student_required():
        return redirect('/login')
    
    db = config.get_db()
    cursor = db.cursor()

    #get students information, then feed advisor id retrieved to grab advisor information
    cursor.callproc('read_student', [session['user_id']])
    student_details = cursor.fetchone()
    cursor.callproc('read_instructor', [student_details['advisor_id']])
    advisor_details = cursor.fetchone()
    cursor.close()
    db.close()


    return render_template('student/advisor.html',
                            advisor_details=advisor_details,
                            student_details=student_details)

@student.route('/student/profile', methods=['GET', 'POST'])
def profile():
    if student_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()    

    #if student wants to change major or password. 
    if request.method == 'POST':
        f = request.form
        cursor.callproc('update_student', [session['user_id'], f['first_name'], f['last_name'], f['dept_name'], f['advisor_id']])
        if f['password']:
            cursor.callproc('change_password', [session['user_id'], f['password']])
        db.commit()
        cursor.close(); db.close()
        return redirect('/student/profile')
     
    #returns student details for display
    cursor.callproc('read_student', [session['user_id']])
    student_details = cursor.fetchone()

    #data for departments drop down menu - change major
    cursor.execute("SELECT dept_name FROM department ORDER BY dept_name")
    departments = cursor.fetchall()

    cursor.close()
    db.close()

    return render_template('student/profile.html', student_details=student_details, departments=departments)
