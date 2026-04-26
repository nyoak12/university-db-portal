import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import io
import base64
import math

def make_chart(labels, values, title=None, color='#4a9eff'):
    fig, ax = plt.subplots(figsize=(8, 5))
    fig.patch.set_facecolor('#001240')
    ax.set_facecolor('#001240')
    bars = ax.bar(labels, values, color=color, alpha=0.8)
    if title:
        ax.set_title(title, color='white', fontsize=13, pad=12)
    ax.tick_params(colors='white', axis='both', labelsize=13)
    ax.tick_params(axis='x', labelrotation=45)
    ax.spines['bottom'].set_color((1, 1, 1, 0.1))
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_color((1, 1, 1, 0.1))
    for bar, val in zip(bars, values):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01,
                f'{val}', ha='center', color='white', fontsize=13)
    plt.tight_layout()
    buf = io.BytesIO()
    plt.savefig(buf, format='png', dpi=120, bbox_inches='tight')
    buf.seek(0)
    chart = base64.b64encode(buf.read()).decode('utf-8')
    plt.close()
    return chart

def chart_avg_by_dept(data):
    return make_chart(
        [r['dept_name'] for r in data],
        [float(r['avg_gpa']) for r in data],
        color='#4a9eff'
    )

def chart_total_by_dept(data):
    return make_chart(
        [r['dept_name'] for r in data],
        [r['total_students'] for r in data],
        color='#34d399'
    )

def chart_enrolled_by_dept(data):
    return make_chart(
        [r['dept_name'] for r in data],
        [r['enrolled_students'] for r in data],
        color='#a78bfa'
    )

def chart_class_range(data, course_id):
    return make_chart(
        [f"{r['semester']} {r['year']}" for r in data],
        [float(r['avg_gpa']) for r in data],
        f'Avg GPA for {course_id} by Term', '#f59e0b'
    )

def chart_best_worst(data, semester, year):
    sorted_data = sorted(data, key=lambda r: float(r['avg_gpa']))
    n = max(1, int(math.log2(len(sorted_data) + 1)))
    worst = sorted_data[:n]
    best = sorted_data[-n:]
    combined = worst + best

    labels = [r['course_id'] for r in combined]
    values = [float(r['avg_gpa']) for r in combined]
    colors = ['#f87171'] * len(worst) + ['#34d399'] * len(best)

    fig, ax = plt.subplots(figsize=(8, 5))
    fig.patch.set_facecolor('#001240')
    ax.set_facecolor('#001240')
    bars = ax.bar(labels, values, color=colors, alpha=0.8)
    ax.set_title(f'Best & Worst Classes {semester} {year}', color='white', fontsize=13, pad=12)
    ax.tick_params(colors='white', axis='both', labelsize=13)
    ax.tick_params(axis='x', labelrotation=45)
    ax.spines['bottom'].set_color((1, 1, 1, 0.1))
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_color((1, 1, 1, 0.1))
    for bar, val in zip(bars, values):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01,
                f'{val}', ha='center', color='white', fontsize=13)
    plt.tight_layout()
    buf = io.BytesIO()
    plt.savefig(buf, format='png', dpi=120, bbox_inches='tight')
    buf.seek(0)
    chart = base64.b64encode(buf.read()).decode('utf-8')
    plt.close()
    return chart