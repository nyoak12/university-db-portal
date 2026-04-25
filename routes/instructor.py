from flask import Blueprint, render_template, redirect, session, request
import config
from datetime import datetime
instructor = Blueprint('instructor', __name__)

def instructor_required():
    return session.get('role') != 'instructor'

@instructor.route('/instructor')
def dashboard():
    if instructor_required():
        return redirect('/login')
    return render_template('instructor/dashboard.html')

@instructor.route('/instructor/grades', methods=['GET', 'POST'])
def grades():
    if instructor_required():
        return redirect('/login')

    # determine most recent completed term
    month = datetime.now().month
    current_year = datetime.now().year
    if month <= 5:
        prev_semester = 'Fall'
        prev_year = current_year - 1
    elif month >= 9:
        prev_semester = 'Summer'
        prev_year = current_year
    else:
        prev_semester = 'Spring'
        prev_year = current_year

    db = config.get_db()
    cursor = db.cursor()

    if request.method == 'POST':
        f = request.form
        cursor.callproc('give_grade', [f['student_id'], f['course_id'], f['sec_id'], f['semester'], f['year'], f['grade']])
        db.commit()
        cursor.close(); db.close()
        return redirect(f"/instructor/grades?course_id={f['course_id']}&sec_id={f['sec_id']}")

    # get instructor's sections for last completed term
    cursor.callproc('get_instructor_sections', [session['user_id'], prev_semester, prev_year])
    sections = cursor.fetchall()

    # get roster if a section is selected
    selected_course = request.args.get('course_id')
    selected_sec = request.args.get('sec_id')
    roster = []
    if selected_course and selected_sec:
        cursor.callproc('get_section_roster', [selected_course, selected_sec, prev_semester, prev_year])
        roster = cursor.fetchall()

    cursor.close()
    db.close()

    grades = ['A','A-','B+','B','B-','C+','C','C-','D+','D','D-','F','W','I']

    return render_template('instructor/grades.html',
                           sections=sections,
                           roster=roster,
                           selected_course=selected_course,
                           selected_sec=selected_sec,
                           prev_semester=prev_semester,
                           prev_year=prev_year,
                           grades=grades)

@instructor.route('/instructor/sections')
def sections():
    if instructor_required():
        return redirect('/login')

    month = datetime.now().month
    current_year = str(datetime.now().year)
    if month <= 5:
        current_semester = 'Spring'
    elif month >= 9:
        current_semester = 'Fall'
    else:
        current_semester = 'Summer'

    db = config.get_db()
    cursor = db.cursor()

    # get all distinct terms this instructor teaches
    cursor.execute("""
        SELECT DISTINCT semester, year FROM teaches
        WHERE ID = %s
        ORDER BY year DESC, FIELD(semester, 'Fall', 'Summer', 'Spring') DESC
        """, [session['user_id']])
    
    terms = cursor.fetchall()
    terms = [dict(t) for t in terms]

    if not any(t['semester'] == current_semester and str(t['year']) == current_year for t in terms):
        terms.insert(0, {'semester': current_semester, 'year': current_year})

    selected_term = request.args.get('term') or f"{current_semester}-{current_year}"
    parts = selected_term.split('-')
    selected_semester = parts[0]
    selected_year = parts[1]

    cursor.callproc('get_instructor_sections', [session['user_id'], selected_semester, selected_year])
    sections = cursor.fetchall()

    cursor.close()
    db.close()

    return render_template('instructor/sections.html',
                           terms=terms,
                           sections=sections,
                           selected_term=selected_term,
                           current_semester=current_semester,
                           current_year=current_year)

@instructor.route('/instructor/roster', methods=['GET', 'POST'])
def roster():
    if instructor_required():
        return redirect('/login')

    if request.method == 'POST':
        f = request.form
        db = config.get_db()
        cursor = db.cursor()
        cursor.callproc('drop_enrollment', [f['student_id'], f['course_id'], f['sec_id'], f['semester'], f['year']])
        db.commit()
        cursor.close(); db.close()
        return redirect(f"/instructor/roster?term={f['term']}&course_id={f['course_id']}&sec_id={f['sec_id']}")

    month = datetime.now().month
    current_year = str(datetime.now().year)
    if month <= 5:
        current_semester = 'Spring'
    elif month >= 9:
        current_semester = 'Fall'
    else:
        current_semester = 'Summer'

    db = config.get_db()
    cursor = db.cursor()

    cursor.execute("""
        SELECT DISTINCT semester, year FROM teaches
        WHERE ID = %s
        ORDER BY year DESC, FIELD(semester, 'Fall', 'Summer', 'Spring') DESC
    """, [session['user_id']])
    terms = [dict(t) for t in cursor.fetchall()]
    if not any(t['semester'] == current_semester and str(t['year']) == current_year for t in terms):
        terms.insert(0, {'semester': current_semester, 'year': current_year})

    selected_term = request.args.get('term') or f"{current_semester}-{current_year}"
    parts = selected_term.split('-')
    selected_semester = parts[0]
    selected_year = parts[1]

    cursor.callproc('get_instructor_sections', [session['user_id'], selected_semester, selected_year])
    sections = cursor.fetchall()

    selected_course = request.args.get('course_id')
    selected_sec = request.args.get('sec_id')
    roster = []
    if selected_course and selected_sec:
        cursor.callproc('get_section_roster', [selected_course, selected_sec, selected_semester, selected_year])
        roster = cursor.fetchall()

    cursor.close()
    db.close()

    return render_template('instructor/roster.html',
                           terms=terms,
                           sections=sections,
                           roster=roster,
                           selected_term=selected_term,
                           selected_course=selected_course,
                           selected_sec=selected_sec,
                           selected_semester=selected_semester,
                           selected_year=selected_year)

@instructor.route('/instructor/advisees', methods=['GET', 'POST'])
def advisees():
    if instructor_required():
        return redirect('/login')

    db = config.get_db()
    cursor = db.cursor()

    if request.method == 'POST':
        f = request.form
        if f['action'] == 'assign':
            cursor.callproc('assign_advisor', [f['student_id'], session['user_id']])
        elif f['action'] == 'drop':
            cursor.callproc('drop_advisee', [f['student_id']])
        db.commit()
        cursor.close(); db.close()
        return redirect('/instructor/advisees')

    cursor.callproc('get_advisees', [session['user_id']])
    advisees = cursor.fetchall()

    cursor.callproc('get_unadvised_students')
    unadvised = cursor.fetchall()

    cursor.close()
    db.close()
    return render_template('instructor/advisees.html', advisees=advisees, unadvised=unadvised)

@instructor.route('/instructor/prereqs', methods=['GET', 'POST'])
def prereqs():
    if instructor_required():
        return redirect('/login')

    db = config.get_db()
    cursor = db.cursor()

    if request.method == 'POST':
        f = request.form
        if f['action'] == 'add':
            cursor.callproc('add_prereq', [f['course_id'], f['prereq_id']])
        elif f['action'] == 'remove':
            cursor.callproc('remove_prereq', [f['course_id'], f['prereq_id']])
        db.commit()
        cursor.close(); db.close()
        return redirect('/instructor/prereqs')

    # get all unique courses this instructor teaches across all terms
    cursor.execute("""
        SELECT DISTINCT t.course_id, c.title
        FROM teaches t
        JOIN course c ON c.course_id = t.course_id
        WHERE t.ID = %s
        ORDER BY t.course_id
    """, [session['user_id']])
    my_courses = cursor.fetchall()

    # get current prereqs for each of those courses
    course_ids = [c['course_id'] for c in my_courses]
    prereqs_map = {c['course_id']: [] for c in my_courses}
    if course_ids:
        fmt = ','.join(['%s'] * len(course_ids))
        cursor.execute(f"""
            SELECT p.course_id, p.prereq_id, c.title
            FROM prereq p
            JOIN course c ON c.course_id = p.prereq_id
            WHERE p.course_id IN ({fmt})
        """, course_ids)
        for row in cursor.fetchall():
            prereqs_map[row['course_id']].append(row)

    # get all courses for the add dropdown
    cursor.execute("SELECT course_id, title FROM course ORDER BY course_id")
    all_courses = cursor.fetchall()

    cursor.close()
    db.close()

    return render_template('instructor/prereqs.html',
                           my_courses=my_courses,
                           prereqs_map=prereqs_map,
                           all_courses=all_courses)

@instructor.route('/instructor/profile', methods=['GET', 'POST'])
def profile():
    if instructor_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()

    if request.method == 'POST':
        f = request.form
        if f['password']:
            cursor.callproc('change_password', [session['user_id'], f['password']])
        db.commit()
        cursor.close(); db.close()
        return redirect('/instructor/profile')

    cursor.callproc('read_instructor', [session['user_id']])
    instructor_details = cursor.fetchone()
    cursor.close()
    db.close()

    return render_template('instructor/profile.html', instructor_details=instructor_details)
