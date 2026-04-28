# KSU University Portal — DB Project Phase 2

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
Make sure MySQL is running, then from the terminal:
```bash
mysql -u root < db.sql
```
This creates the `ksu` schema, all 16 tables, stored procedures, and seed data.

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

Passwords are stored as SHA-256 hashes in the `login` table.

| Role       | Username        | Password       |
|------------|-----------------|----------------|
| Admin      | testadmin       | password123    |
| Instructor | testinstructor  | instructor123  |
| Student    | teststudent     | student123     |

To insert a new user manually (admin example):
```sql
USE ksu;
INSERT INTO admin VALUES('A03', 'Test', 'Admin');
INSERT INTO login VALUES('A03', 'testadmin', SHA2('password123', 256), 'admin');
```

---

## Folder Structure

```
university-db-portal/
├── app.py                  # registers all blueprints, runs the app
├── config.py               # DB connection — NOT in repo, create manually (see setup step 5)
├── db.sql                  # schema, tables, stored procedures, and seed data
├── requirements.txt        # Python dependencies
├── routes/
│   ├── __init__.py         # marks routes/ as a Python package
│   ├── auth.py             # login, logout, session management
│   ├── admin.py            # all /admin/* routes and CRUD logic
│   ├── instructor.py       # all /instructor/* routes
│   ├── student.py          # all /student/* routes
│   └── plots.py            # Matplotlib chart generation for analytics
└── templates/
    ├── layout.html         # shared base: gradient bg, navbar, flash messages, CSS classes
    ├── login.html          # login page
    ├── admin/
    │   ├── dashboard.html  # admin dashboard
    │   ├── students.html   # CRUD students
    │   ├── instructors.html# CRUD instructors
    │   ├── courses.html    # CRUD courses
    │   ├── sections.html   # CRUD sections
    │   ├── departments.html# CRUD departments
    │   ├── classrooms.html # CRUD classrooms
    │   ├── timeslots.html  # CRUD time slots
    │   ├── teaches.html    # assign/remove instructors to sections
    │   ├── queries.html    # analytics dashboard with charts
    │   └── admin_profile.html # admin profile and password reset
    ├── instructor/
    │   ├── dashboard.html  # instructor dashboard
    │   ├── grades.html     # submit and modify grades
    │   ├── sections.html   # view assigned sections by term
    │   ├── roster.html     # view section roster, drop students
    │   ├── advisees.html   # manage advisees
    │   ├── prereqs.html    # manage course prerequisites
    │   └── profile.html    # instructor profile and password reset
    └── student/
        ├── dashboard.html  # student dashboard
        ├── register.html   # register for classes
        ├── drop.html       # drop enrolled classes
        ├── schedule.html   # view current schedule
        ├── transcript.html # view grades and GPA
        ├── advisor.html    # view advisor information
        └── profile.html    # student profile, major change, password reset
```

---

## Shared CSS Classes

Defined in `layout.html` and available across all templates:

| Class         | Use                              |
|---------------|----------------------------------|
| `glass-card`  | Dashboard cards, info panels     |
| `glass-input` | Form inputs and dropdowns        |
| `glass-table` | Data tables on list/CRUD pages   |

---

## Tech Stack

| Layer            | Technology                        |
|------------------|-----------------------------------|
| Backend          | Python, Flask                     |
| Database         | MySQL (16 tables, 46+ procedures) |
| Templating       | Jinja2                            |
| Styling          | Tailwind CSS                      |
| Charts           | Matplotlib                        |
| Authentication   | Flask Sessions + SHA-256 hashing  |
