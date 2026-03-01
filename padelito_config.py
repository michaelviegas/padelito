#!/usr/bin/env python3
from flask import Flask, render_template, request, jsonify
import os
import re

app = Flask(__name__)
DATA_FILE = '/home/pi/padelito/padelito.data'

def read_config():
    """Read configuration from padelito.data file"""
    config = {
        'TOKEN_ID': '',
        'CLUB_ID': '',
        'DAYS_TO_ADD': '',
        'COURT_IDS': '',
        'HOURS': '',
        'BOT_ID': '',
        'CHAT_ID': ''
    }
    
    try:
        if os.path.exists(DATA_FILE):
            with open(DATA_FILE, 'r') as f:
                for line in f:
                    line = line.strip()
                    if '=' in line and not line.startswith('#'):
                        key, value = line.split('=', 1)
                        key = key.strip()
                        value = value.strip()
                        if key in config:
                            config[key] = value
    except Exception as e:
        print(f'Error reading file: {str(e)}')
    
    return config

def write_config(config):
    """Write configuration to padelito.data file"""
    try:
        os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
        with open(DATA_FILE, 'w') as f:
            f.write(f"TOKEN_ID={config['TOKEN_ID']}\n")
            f.write(f"CLUB_ID={config['CLUB_ID']}\n")
            f.write(f"DAYS_TO_ADD={config['DAYS_TO_ADD']}\n")
            f.write(f"COURT_IDS={config['COURT_IDS']}\n")
            f.write(f"HOURS={config['HOURS']}\n")
            f.write(f"BOT_ID={config['BOT_ID']}\n")
            f.write(f"CHAT_ID={config['CHAT_ID']}\n")
        return True, 'Configuration saved successfully!'
    except Exception as e:
        return False, f'Error writing file: {str(e)}'

def read_cron():
    """Read current cron job for pi user"""
    try:
        import subprocess
        result = subprocess.run(['crontab', '-l'], 
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            # Look for the bookcourt.sh line
            for line in result.stdout.strip().split('\n'):
                if 'bookcourt.sh' in line and not line.strip().startswith('#'):
                    return line.strip()
        return ''
    except Exception as e:
        print(f'Error reading cron: {str(e)}')
        return ''

def write_cron(cron_line):
    """Write cron job for pi user"""
    try:
        import subprocess
        
        # Get existing crontab
        result = subprocess.run(['crontab', '-l'], 
                              capture_output=True, text=True, timeout=5)
        
        existing_lines = []
        if result.returncode == 0:
            existing_lines = result.stdout.strip().split('\n')
        
        # Remove old bookcourt.sh entries
        new_lines = [line for line in existing_lines 
                    if 'bookcourt.sh' not in line or line.strip().startswith('#')]
        
        # Add new cron line if not empty
        if cron_line.strip():
            new_lines.append(cron_line.strip())
        
        # Write new crontab
        new_crontab = '\n'.join(new_lines) + '\n'
        result = subprocess.run(['crontab', '-'], 
                              input=new_crontab, 
                              capture_output=True, 
                              text=True, 
                              timeout=5)
        
        if result.returncode == 0:
            # Restart cron service
            subprocess.run(['sudo', 'systemctl', 'restart', 'cron'], 
                         capture_output=True, timeout=10)
            return True, 'Cron job updated and cron service restarted!'
        else:
            return False, f'Error updating cron: {result.stderr}'
            
    except Exception as e:
        return False, f'Error writing cron: {str(e)}'

@app.route('/')
def index():
    """Main page with configuration editor"""
    config = read_config()
    cron_job = read_cron()
    return render_template('index.html', config=config, cron_job=cron_job)

@app.route('/update', methods=['POST'])
def update_config():
    """Update configuration via AJAX"""
    config = {
        'TOKEN_ID': request.form.get('TOKEN_ID', '').strip(),
        'CLUB_ID': request.form.get('CLUB_ID', '').strip(),
        'DAYS_TO_ADD': request.form.get('DAYS_TO_ADD', '').strip(),
        'COURT_IDS': request.form.get('COURT_IDS', '').strip(),
        'HOURS': request.form.get('HOURS', '').strip(),
        'BOT_ID': request.form.get('BOT_ID', '').strip(),
        'CHAT_ID': request.form.get('CHAT_ID', '').strip()
    }
    
    success, message = write_config(config)
    return jsonify({'success': success, 'message': message})

@app.route('/update-cron', methods=['POST'])
def update_cron():
    """Update cron job via AJAX"""
    cron_line = request.form.get('cron_job', '').strip()
    success, message = write_cron(cron_line)
    return jsonify({'success': success, 'message': message})

@app.route('/restart-cron', methods=['POST'])
def restart_cron():
    """Restart cron service"""
    try:
        import subprocess
        result = subprocess.run(['sudo', 'systemctl', 'restart', 'cron'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            return jsonify({'success': True, 'message': 'Cron service restarted successfully!'})
        else:
            return jsonify({'success': False, 'message': f'Error: {result.stderr}'})
    except Exception as e:
        return jsonify({'success': False, 'message': f'Error restarting cron: {str(e)}'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80, debug=False)
