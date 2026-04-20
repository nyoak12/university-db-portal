from flask import Blueprint, render_template, redirect, session
import config

instructor = Blueprint('instructor', __name__)

def instructor_required():
    return session.get('role') != 'instructor'

@instructor.route('/instructor')
def dashboard():
    if instructor_required():
        return redirect('/login')
    return render_template('instructor/dashboard.html')

@instructor.route('/instructor/grades')
def grades():
    if instructor_required():
        return redirect('/login')
    return render_template('instructor/grades.html')

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

@instructor.route('/instructor/advisees')
def advisees():
    if instructor_required():
        return redirect('/login')
    return render_template('instructor/advisees.html')

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
