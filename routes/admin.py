from flask import Blueprint, render_template, redirect, session
import config

admin = Blueprint('admin', __name__)

def admin_required():
    return session.get('role') != 'admin'

@admin.route('/admin')
def dashboard():
    if admin_required():
        return redirect('/login')
    return render_template('admin/dashboard.html')

# Students
@admin.route('/admin/students')
def students():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    cursor.callproc('get_all_students')
    students = cursor.fetchall()
    cursor.close()
    db.close()
    return render_template('admin/students.html', students=students)

# Instructors
@admin.route('/admin/instructors')
def instructors():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    cursor.callproc('get_all_instructors')
    instructors = cursor.fetchall()
    cursor.close()
    db.close()
    return render_template('admin/instructors.html', instructors=instructors)

# Courses
@admin.route('/admin/courses')
def courses():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    cursor.callproc('get_all_courses')
    courses = cursor.fetchall()
    cursor.close()
    db.close()
    return render_template('admin/courses.html', courses=courses)

# Sections
@admin.route('/admin/sections')
def sections():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    cursor.callproc('get_all_sections')
    sections = cursor.fetchall()
    cursor.close()
    db.close()
    return render_template('admin/sections.html', sections=sections)

# Departments
@admin.route('/admin/departments')
def departments():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    cursor.callproc('get_all_departments')
    departments = cursor.fetchall()
    cursor.close()
    db.close()
    return render_template('admin/departments.html', departments=departments)

# Classrooms
@admin.route('/admin/classrooms')
def classrooms():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    cursor.callproc('get_all_classrooms')
    classrooms = cursor.fetchall()
    cursor.close()
    db.close()
    return render_template('admin/classrooms.html', classrooms=classrooms)

# Time Slots
@admin.route('/admin/timeslots')
def timeslots():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    cursor.callproc('get_all_timeslots')
    timeslots = cursor.fetchall()
    cursor.close()
    db.close()
    return render_template('admin/timeslots.html', timeslots=timeslots)
