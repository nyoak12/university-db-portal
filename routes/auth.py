from flask import Blueprint, render_template, request, redirect, session
import config
import pymysql

auth = Blueprint('auth', __name__)

@auth.route('/')
def index():
    if 'user_id' in session:
        return redirect('/' + session['role'])
    return redirect('/login')

@auth.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')

    username = request.form['username']
    password = request.form['password']

    db = config.get_db()
    cursor = db.cursor()

    try:
        cursor.callproc('user_login', [username, password])
        user = cursor.fetchone()
        session['user_id'] = user['ID']
        session['role'] = user['role']
        session['first_name'] = user['first_name']
        session['last_name'] = user['last_name']
        return redirect('/' + user['role'])
    except pymysql.err.OperationalError:
        return render_template('login.html', error='Invalid username or password')
    finally:
        cursor.close()
        db.close()

@auth.route('/logout')
def logout():
    session.clear()
    return redirect('/login')
