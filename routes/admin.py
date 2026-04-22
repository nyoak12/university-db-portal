from flask import Blueprint, render_template, redirect, session, request, flash
import config
import re

admin = Blueprint('admin', __name__)

def admin_required():
    return session.get('role') != 'admin'

@admin.route('/admin')
def dashboard():
    if admin_required():
        return redirect('/login')
    return render_template('admin/dashboard.html')

# ──────────────────Students──────────────────────────────────────────────────────────────────────────────────────────
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
    cursor = db.cursor()
    cursor.callproc('get_all_departments')
    departments = cursor.fetchall()
    cursor.close()
    cursor = db.cursor()
    cursor.callproc('get_all_instructors')
    instructors = cursor.fetchall()
    cursor.close()
    db.close()
    return render_template('admin/students.html', students=students, departments=departments, instructors=instructors)

# Create Student
@admin.route('/admin/students/create', methods=['POST'])
def create_student():
    if admin_required():
        return redirect('/login')
    student_id = request.form['ID']
    if not re.match(r'^S\d{5}$', student_id):
        flash('Student ID must start with S followed by 5 digits (e.g. S00501).', 'error')
        return redirect('/admin/students')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('create_student', [
            student_id,
            request.form['first_name'],
            request.form['last_name'],
            request.form['dept_name'] or None,
            request.form['advisor_id'] or None,
            request.form['username'],
            request.form['password']
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        msg = e.args[1] if len(e.args) > 1 else str(e)
        if 'duplicate entry' in msg.lower():
            flash('A student with this ID already exists.', 'error')
        else:
            flash(msg, 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/students')

# Update Student
@admin.route('/admin/students/update', methods=['POST'])
def update_student():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('update_student', [
            request.form['ID'],
            request.form['first_name'],
            request.form['last_name'],
            request.form['dept_name'] or None,
            request.form['advisor_id'] or None
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        flash(e.args[1] if len(e.args) > 1 else str(e), 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/students')

# Delete Student
@admin.route('/admin/students/delete', methods=['POST'])
def delete_student():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('delete_student', [
            request.form['ID']
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        flash(e.args[1] if len(e.args) > 1 else str(e), 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/students')

# ──────────────────Instructors──────────────────────────────────────────────────────────────────────────────────────────
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
    cursor = db.cursor()
    cursor.callproc('get_all_departments')
    departments = cursor.fetchall()
    cursor.close()
    db.close()
    return render_template('admin/instructors.html', instructors=instructors, departments=departments)

# Create Instructor
@admin.route('/admin/instructors/create', methods=['POST'])
def create_instructor():
    if admin_required():
        return redirect('/login')
    instructor_id = request.form['ID']
    if not re.match(r'^I\d{5}$', instructor_id):
        flash('Instructor ID must start with I followed by 5 digits (e.g. I00030).', 'error')
        return redirect('/admin/instructors')
    salary = request.form['salary'] or None
    if salary and float(salary) <= 29000:
        flash('Salary must be greater than $29,000.', 'error')
        return redirect('/admin/instructors')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('create_instructor', [
            instructor_id,
            request.form['first_name'],
            request.form['last_name'],
            request.form['dept_name'] or None,
            salary,
            request.form['username'],
            request.form['password']
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        flash(e.args[1] if len(e.args) > 1 else str(e), 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/instructors')

# Update Instructor
@admin.route('/admin/instructors/update', methods=['POST'])
def update_instructor():
    if admin_required():
        return redirect('/login')
    salary = request.form['salary'] or None
    if salary and float(salary) <= 29000:
        flash('Salary must be greater than $29,000.', 'error')
        return redirect('/admin/instructors')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('update_instructor', [
            request.form['ID'],
            request.form['first_name'],
            request.form['last_name'],
            request.form['dept_name'] or None,
            salary
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        flash(e.args[1] if len(e.args) > 1 else str(e), 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/instructors')

# Delete Instructor
@admin.route('/admin/instructors/delete', methods=['POST'])
def delete_instructor():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('delete_instructor', [
            request.form['ID']
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        flash(e.args[1] if len(e.args) > 1 else str(e), 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/instructors')

# ──────────────────Courses──────────────────────────────────────────────────────────────────────────────────────────
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
    cursor = db.cursor()
    cursor.callproc('get_all_departments')
    departments = cursor.fetchall()
    cursor.close()
    db.close()
    return render_template('admin/courses.html', courses=courses, departments=departments)

# Create Course
@admin.route('/admin/courses/create', methods=['POST'])
def create_course():
    if admin_required():
        return redirect('/login')
    course_id = request.form['course_id']
    if not re.match(r'^[A-Z]{2,4}-\d{3,4}$', course_id):
        flash('Course ID must follow the format: XXX-000 (e.g. CS-347, BIO-101)', 'error')
        return redirect('/admin/courses')
    credits = request.form['credits'] or None
    if credits and (int(credits) < 1 or int(credits) > 6):
        flash('Credits must be between 1 and 6.', 'error')
        return redirect('/admin/courses')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('create_course', [
            course_id,
            request.form['title'],
            request.form['dept_name'] or None,
            credits
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        flash(e.args[1] if len(e.args) > 1 else str(e), 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/courses')

# Update Course
@admin.route('/admin/courses/update', methods=['POST'])
def update_course():
    if admin_required():
        return redirect('/login')
    credits = request.form['credits'] or None
    if credits and (int(credits) < 1 or int(credits) > 6):
        flash('Credits must be between 1 and 6.', 'error')
        return redirect('/admin/courses')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('update_course', [
            request.form['course_id'],
            request.form['title'],
            request.form['dept_name'] or None,
            credits
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        flash(e.args[1] if len(e.args) > 1 else str(e), 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/courses')

# Delete Course
@admin.route('/admin/courses/delete', methods=['POST'])
def delete_course():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('delete_course', [
            request.form['course_id']
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        flash(e.args[1] if len(e.args) > 1 else str(e), 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/courses')

# ──────────────────Sections──────────────────────────────────────────────────────────────────────────────────────────
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

# ──────────────────Departments──────────────────────────────────────────────────────────────────────────────────────────
@admin.route('/admin/departments')
def departments():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    cursor.callproc('get_all_departments')
    departments = cursor.fetchall()
    cursor.nextset()
    cursor.callproc('get_all_buildings')
    buildings = cursor.fetchall()
    cursor.close()
    db.close()
    return render_template('admin/departments.html', departments=departments, buildings=buildings)

# Create Departments
@admin.route('/admin/departments/create', methods=['POST'])
def create_department():
    if admin_required():
        return redirect('/login')
    budget = request.form['budget'] or None
    if budget and float(budget) < 0:
        flash('Budget cannot be negative.', 'error')
        return redirect('/admin/departments')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('create_department', [
            request.form['dept_name'],
            request.form['building_id'] or None,
            budget
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        msg = e.args[1] if len(e.args) > 1 else str(e)
        if 'out of range' in msg.lower():
            flash('Budget value is too large. Please enter a realistic amount.', 'error')
        elif 'foreign key' in msg.lower():
            flash('Please select a valid building from the list.', 'error')
        else:
            flash(msg, 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/departments')

# Update Departments
@admin.route('/admin/departments/update', methods=['POST'])
def update_department():
    if admin_required():
        return redirect('/login')
    budget = request.form['budget'] or None
    if budget and float(budget) < 0:
        flash('Budget cannot be negative.', 'error')
        return redirect('/admin/departments')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('update_department', [
            request.form['dept_name'],
            request.form['building_id'] or None,
            budget
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        msg = e.args[1] if len(e.args) > 1 else str(e)
        if 'out of range' in msg.lower():
            flash('Budget value is too large. Please enter a realistic amount.', 'error')
        else:
            flash(msg, 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/departments')

# Delete Departments
@admin.route('/admin/departments/delete', methods=['POST'])
def delete_department():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('delete_department', [
            request.form['dept_name'],
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        flash(e.args[1] if len(e.args) > 1 else str(e), 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/departments')

# ──────────────────Classrooms──────────────────────────────────────────────────────────────────────────────────────────
@admin.route('/admin/classrooms')
def classrooms():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    cursor.callproc('get_all_classrooms')
    classrooms = cursor.fetchall()
    cursor.nextset()
    cursor.callproc('get_all_buildings')
    buildings = cursor.fetchall()
    cursor.close()
    db.close()
    return render_template('admin/classrooms.html', classrooms=classrooms, buildings=buildings)

# Create Classroom
@admin.route('/admin/classrooms/create', methods=['POST'])
def create_classroom():
    if admin_required():
        return redirect('/login')
    room_number = request.form['room_number']
    if not room_number.isalnum():
        flash('Invalid room number. Use only letters and numbers.', 'error')
        return redirect('/admin/classrooms')
    capacity = request.form['capacity'] or None
    if capacity:
        if int(capacity) > 500:
            flash('Capacity cannot exceed 500.', 'error')
            return redirect('/admin/classrooms')
        if int(capacity) < 1:
            flash('Capacity cannot be zero or negative.', 'error')
            return redirect('/admin/classrooms')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('create_classroom', [
            request.form['building_id'] or None,
            room_number,
            capacity
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        flash(e.args[1] if len(e.args) > 1 else str(e), 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/classrooms')

# Update Classroom
@admin.route('/admin/classrooms/update', methods=['POST'])
def update_classroom():
    if admin_required():
        return redirect('/login')
    capacity = request.form['capacity'] or None
    if capacity:
        if int(capacity) > 500:
            flash('Capacity cannot exceed 500.', 'error')
            return redirect('/admin/classrooms')
        if int(capacity) < 1:
            flash('Capacity cannot be zero or negative.', 'error')
            return redirect('/admin/classrooms')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('update_classroom', [
            request.form['building_id'],
            request.form['room_number'],
            capacity
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        flash(e.args[1] if len(e.args) > 1 else str(e), 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/classrooms')

# Delete Classroom
@admin.route('/admin/classrooms/delete', methods=['POST'])
def delete_classroom():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    try:
        cursor.callproc('delete_classroom', [
            request.form['building_id'],
            request.form['room_number']
        ])
        db.commit()
    except Exception as e:
        db.rollback()
        flash(e.args[1] if len(e.args) > 1 else str(e), 'error')
    finally:
        cursor.close()
        db.close()
    return redirect('/admin/classrooms')

# ──────────────────Time Slots──────────────────────────────────────────────────────────────────────────────────────────
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
