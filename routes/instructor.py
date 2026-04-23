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
    return render_template('instructor/sections.html')

@instructor.route('/instructor/roster')
def roster():
    if instructor_required():
        return redirect('/login')
    return render_template('instructor/roster.html')

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

@instructor.route('/instructor/prereqs')
def prereqs():
    if instructor_required():
        return redirect('/login')
    return render_template('instructor/prereqs.html')

@instructor.route('/instructor/profile')
def profile():
    if instructor_required():
        return redirect('/login')
    return render_template('instructor/profile.html')
