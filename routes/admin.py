from flask import Blueprint, render_template, redirect, session, request, flash
import config

admin = Blueprint('admin', __name__)

def admin_required():
    return session.get('role') != 'admin'

@admin.route('/admin')
def dashboard():
    if admin_required():
        return redirect('/login')
    return render_template('admin/dashboard.html')

# ──────────────────Students──────────────────────────────────────────────────────────────────────────────────────────
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

# ──────────────────Instructors──────────────────────────────────────────────────────────────────────────────────────────
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

# ──────────────────Courses──────────────────────────────────────────────────────────────────────────────────────────
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
