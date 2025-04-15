from flask import Flask, jsonify
from flask_socketio import SocketIO
from datetime import datetime
from geopy.distance import geodesic
import logging
import eventlet
import os

# Важно: отключаем стандартный eventlet monkey patching
eventlet.monkey_patch(os=False, select=False, socket=True, thread=True)

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'your_secret_key_here')

# Используем async_mode='eventlet' и отключаем логирование engineio
socketio = SocketIO(app, 
                   cors_allowed_origins="*",
                   async_mode='eventlet',
                   engineio_logger=False,
                   logger=False)

users = {}

def calculate_distance(lat1, lon1, lat2, lon2):
    return geodesic((lat1, lon1), (lat2, lon2)).meters

@app.route('/')
def status():
    return jsonify({
        'status': 'running',
        'users_online': len(users)
    })

@socketio.on('connect')
def handle_connect():
    logging.info(f'Client connected: {request.sid}')

@socketio.on('disconnect')
def handle_disconnect():
    for user_id, data in list(users.items()):
        if data['sid'] == request.sid:
            logging.info(f'User disconnected: {user_id}')
            del users[user_id]
            socketio.emit('user_disconnected', user_id)
            break

@socketio.on('register')
def handle_register(user_id):
    if user_id not in users:
        users[user_id] = {
            'sid': request.sid,
            'position': None
        }
        logging.info(f'User registered: {user_id}')
        socketio.emit('user_connected', user_id)

@socketio.on('bump')
def handle_bump(data):
    sender_id = data.get('senderId')
    if sender_id not in users:
        return

    users[sender_id]['position'] = (
        data.get('lat'),
        data.get('lng'),
        data.get('accuracy'),
        data.get('speed')
    )

    for receiver_id, receiver_data in users.items():
        if receiver_id == sender_id or not receiver_data['position']:
            continue

        distance = calculate_distance(
            users[sender_id]['position'][0], users[sender_id]['position'][1],
            receiver_data['position'][0], receiver_data['position'][1]
        )

        if distance < 50:  # 50m threshold
            socketio.emit('bump_event', {
                'senderId': sender_id,
                'distance': distance,
                'timestamp': datetime.now().isoformat()
            }, room=receiver_data['sid'])

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    port = int(os.environ.get('PORT', 10000))
    socketio.run(app, host='0.0.0.0', port=port)