from flask import Flask
from routes.auth import auth
from routes.admin import admin
from routes.instructor import instructor
from routes.student import student

app = Flask(__name__)
app.secret_key = 'dev-secret-key'

app.register_blueprint(auth)
app.register_blueprint(admin)
app.register_blueprint(instructor)
app.register_blueprint(student)

app.run(host='localhost', port=4500, debug=True)
