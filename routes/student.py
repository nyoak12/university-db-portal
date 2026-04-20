from flask import Blueprint, render_template, redirect, session
import config

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
    return render_template('student/register.html')

@student.route('/student/drop')
def drop():
    if student_required():
        return redirect('/login')
    return render_template('student/drop.html')

@student.route('/student/grades')
def grades():
    if student_required():
        return redirect('/login')
    return render_template('student/grades.html')

@student.route('/student/schedule')
def schedule():
    if student_required():
        return redirect('/login')
    return render_template('student/schedule.html')

@student.route('/student/advisor')
def advisor():
    if student_required():
        return redirect('/login')
    return render_template('student/advisor.html')

@student.route('/student/profile')
def profile():
    if student_required():
        return redirect('/login')
    return render_template('student/profile.html')
