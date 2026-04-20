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
    return render_template('admin/instructors.html')

# Courses
@admin.route('/admin/courses')
def courses():
    if admin_required():
        return redirect('/login')
    return render_template('admin/courses.html')

# Sections
@admin.route('/admin/sections')
def sections():
    if admin_required():
        return redirect('/login')
    return render_template('admin/sections.html')

# Departments
@admin.route('/admin/departments')
def departments():
    if admin_required():
        return redirect('/login')
    return render_template('admin/departments.html')

# Classrooms
@admin.route('/admin/classrooms')
def classrooms():
    if admin_required():
        return redirect('/login')
    return render_template('admin/classrooms.html')

# Time Slots
@admin.route('/admin/timeslots')
def timeslots():
    if admin_required():
        return redirect('/login')
    return render_template('admin/timeslots.html')
