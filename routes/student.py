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
    return render_template('student/dashboard.html')

@student.route('/student/register')
def register():
    if student_required():
        return redirect('/login')
    
    db = config.get_db()
    cursor = db.cursor()
    
    current_year = datetime.now().year
    cursor.execute("SELECT DISTINCT semester, year FROM section WHERE year >= %s ORDER BY year, semester", (current_year,))
    terms = cursor.fetchall()
    unique_semesters = sorted({term['semester'] for term in terms})
    unique_years = sorted({str(term['year']) for term in terms}, reverse=True)

    selected_semester = request.args.get('semester')
    selected_year = request.args.get('year')
    if selected_semester and selected_year:
        cursor.callproc('get_sections_by_term', [selected_semester, selected_year])
        classes_for_registering = cursor.fetchall()
    else:
        classes_for_registering = []
    
   
    cursor.close()
    db.close()
    return render_template('student/register.html', 
                           classes_for_registering=classes_for_registering,
                           unique_semesters=unique_semesters,
                           unique_years=unique_years, 
                           selected_semester=selected_semester,
                           selected_year=selected_year)

@student.route('/student/drop')
def drop():
    if student_required():
        return redirect('/login')
    return render_template('student/drop.html')

@student.route('/student/transcript')
def transcript():
    if student_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    cursor.callproc('read_student_transcript', [session['user_id']])
    transcript = cursor.fetchall()
    cursor.close()
    db.close()


    grade_list = [row['points'] for row in transcript if row['letter_grade'] not in ('W', 'I')]
    grade_average = sum(grade_list)/ len(grade_list) if grade_list else 0.0

    return render_template('student/transcript.html', transcript=transcript, grade_average=grade_average)

@student.route('/student/schedule')
def schedule():
    if student_required():
        return redirect('/login')
    
    db = config.get_db()
    cursor = db.cursor()
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
    cursor.callproc('read_student', [session['user_id']])
    student_details = cursor.fetchone()
    cursor.callproc('read_instructor', [student_details['advisor_id']])
    advisor_details = cursor.fetchone()
    cursor.close()
    db.close()


    return render_template('student/advisor.html',
                            advisor_details=advisor_details,
                            student_details=student_details)

@student.route('/student/profile')
def profile():
    if student_required():
        return redirect('/login')
    return render_template('student/profile.html')
