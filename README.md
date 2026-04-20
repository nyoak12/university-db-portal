# University Login Portal — DB Project Phase 2

Flask web app for a university database system. Role-based access for admin, instructor, and student.

---

## Setup

### 1. Clone the repo and navigate into the project
```bash
cd university-db-portal
```

### 2. Create and activate the virtual environment
```bash
python3 -m venv .venv
source .venv/bin/activate
```

### 3. Install dependencies
```bash
pip install -r requirements.txt
```

### 4. Load the database into MySQL
Make sure MySQL is running, then from the VS Code terminal:
```bash
mysql -u root < db.sql
```
This creates the `ksu` schema, all tables, and all stored procedures.

### 5. Create config.py
`config.py` is intentionally not in the repo (it contains your local DB credentials). Create it manually in `university-db-portal/`:
```python
import pymysql

def get_db():
    return pymysql.connect(
        host="localhost",
        user="root",
        password="",        # your MySQL root password (blank if none)
        database="ksu",
        autocommit=False,
        cursorclass=pymysql.cursors.DictCursor
    )
```

### 6. Run the app
```bash
python app.py
```
App runs at: http://localhost:4500

---

## Test Logins

These accounts were inserted manually into the `ksu` database for testing. Passwords are stored as SHA-256 hashes — querying `SELECT * FROM login` will show the encrypted values, not plaintext.

| Role       | Username        | Password       |
|------------|-----------------|----------------|
| Admin      | testadmin       | password123    |
| Instructor | testinstructor  | instructor123  |
| Student    | teststudent     | student123     |

To insert a new user manually, follow this pattern (admin example):
```sql
USE ksu;

INSERT INTO admin VALUES('A03', 'Test', 'Admin');
INSERT INTO login VALUES('A03', 'testadmin', SHA2('password123', 256), 'admin');
```

> Note: A stored procedure for user creation has not been written yet. Until then, use the pattern above.

---

## Folder Structure

Routes are already defined for all pages below. Templates marked `[TODO]` still need to be created.

```
university-db-portal/
├── app.py                  # registers all blueprints, runs the app
├── config.py               # DB connection — NOT in repo, create your own (see setup step 5)
├── db.sql                  # DDL: schema, tables, stored procedures
├── routes/
│   ├── __init__.py         # marks routes/ as a Python package
│   ├── auth.py             # login, logout, index redirect
│   ├── admin.py            # all /admin/* routes — TODO: wire up DB queries
│   ├── instructor.py       # all /instructor/* routes — TODO: wire up DB queries
│   └── student.py          # all /student/* routes — TODO: wire up DB queries
└── templates/
    ├── layout.html         # shared base: gradient bg, navbar, CSS classes
    ├── login.html          # login page
    ├── admin/
    │   ├── dashboard.html  # admin dashboard cards
    │   ├── students.html   # [TODO] list/CRUD students
    │   ├── instructors.html# [TODO] list/CRUD instructors
    │   ├── courses.html    # [TODO] list/CRUD courses
    │   ├── sections.html   # [TODO] list/CRUD sections
    │   ├── departments.html# [TODO] list/CRUD departments
    │   ├── classrooms.html # [TODO] list/CRUD classrooms
    │   └── timeslots.html  # [TODO] list/CRUD time slots
    ├── instructor/
    │   ├── dashboard.html  # instructor dashboard cards
    │   ├── grades.html     # [TODO] submit grades
    │   ├── sections.html   # [TODO] view my sections
    │   ├── roster.html     # [TODO] view section roster
    │   ├── advisees.html   # [TODO] view advisees
    │   ├── prereqs.html    # [TODO] view course prerequisites
    │   └── profile.html    # [TODO] instructor profile
    └── student/
        ├── dashboard.html  # student dashboard cards
        ├── register.html   # [TODO] register for classes
        ├── drop.html       # [TODO] drop classes
        ├── grades.html     # [TODO] view my grades
        ├── schedule.html   # [TODO] view my schedule
        ├── advisor.html    # [TODO] view my advisor
        └── profile.html    # [TODO] student profile
```

---

## Adding New Pages

Each card on the dashboard links to a route. For every new page you need to:

**1. Add a route in the relevant routes file**

Example — adding a students list page in `routes/admin.py`:
```python
@admin.route('/admin/students')
def students():
    if admin_required():
        return redirect('/login')
    db = config.get_db()
    cursor = db.cursor()
    cursor.callproc('get_all_students')   # stored procedure (see note below)
    students = cursor.fetchall()
    cursor.close()
    db.close()
    return render_template('admin/students.html', students=students)
```

**2. Create the HTML template in the matching folder**

Example — `templates/admin/students.html`:
```html
{% extends 'layout.html' %}
{% block title %}Students{% endblock %}
{% block nav_title %}KSU ADMIN{% endblock %}

{% block content %}
<!-- your table/form content here -->
{% endblock %}
```

**3. Reuse shared CSS classes from layout.html**

| Class          | Use                              |
|----------------|----------------------------------|
| `glass-card`   | Dashboard cards, panels          |
| `glass-input`  | Form inputs                      |
| `glass-table`  | Data tables on list/CRUD pages       |

---

## Stored Procedures Note

The routes that list all records (students, instructors, courses, etc.) will call a `SELECT *` stored procedure. You need to add one to `db.sql` for each entity before those routes will work. Below is the example procedure added for admin route for students card. Click on students in the admin console to preview what each card should return as boilerplate before adding CRUD operations and more.

Example procedure added:
```sql
DELIMITER $$
CREATE PROCEDURE get_all_students()
BEGIN
    SELECT * FROM student;
END $$
DELIMITER ;
```

Add similar procedures for: instructors, courses, sections, departments, classrooms, timeslots.
