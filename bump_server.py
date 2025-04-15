from flask import Flask, jsonify, request
from flask_socketio import SocketIO, emit
from datetime import datetime
from geopy.distance import geodesic
import logging
import eventlet
from math import radians, sin, cos, sqrt, atan2

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your_secret_key_here'
socketio = SocketIO(app, cors_allowed_origins="*", logger=True, engineio_logger=True)
eventlet.monkey_patch()

# Хранилище данных
users = {}  # {user_id: {'sid': sid, 'position': (lat, lng, accuracy, speed)}}

def calculate_distance(lat1, lon1, lat2, lon2):
    R = 6371000  # Earth radius in meters
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    return R * 2 * atan2(sqrt(a), sqrt(1-a))

@app.route('/')
def dashboard():
    return jsonify({
        'status': 'running',
        'users_count': len(users),
        'users': list(users.keys())
    })

@socketio.on('connect')
def handle_connect():
    logging.info(f'Client connected: {request.sid}')

@socketio.on('disconnect')
def handle_disconnect():
    for user_id, user_data in list(users.items()):
        if user_data['sid'] == request.sid:
            logging.info(f'User disconnected: {user_id}')
            del users[user_id]
            emit('user_disconnected', user_id, broadcast=True)
            break

@socketio.on('register')
def handle_register(user_id):
    if user_id not in users:
        users[user_id] = {
            'sid': request.sid,
            'position': None
        }
        logging.info(f'User registered: {user_id}')
        emit('registration_success', {'status': 'OK'})
        emit('user_connected', {
            'userId': user_id,
            'usersOnline': list(users.keys())
        }, broadcast=True)

@socketio.on('bump')
def handle_bump(data):
    sender_id = data.get('senderId')
    if sender_id not in users:
        return

    # Обновляем позицию пользователя
    users[sender_id]['position'] = (
        data.get('lat'),
        data.get('lng'),
        data.get('accuracy'),
        data.get('speed')
    )

    # Ищем ближайших пользователей (50m radius)
    for receiver_id, receiver_data in users.items():
        if receiver_id == sender_id or not receiver_data['position']:
            continue

        sender_pos = users[sender_id]['position']
        receiver_pos = receiver_data['position']
        
        distance = calculate_distance(
            sender_pos[0], sender_pos[1],
            receiver_pos[0], receiver_pos[1]
        )

        if distance < 50:  # 50 meters threshold
            emit('bump_event', {
                'senderId': sender_id,
                'distance': distance,
                'timestamp': datetime.now().isoformat(),
                'location': {
                    'lat': sender_pos[0],
                    'lng': sender_pos[1]
                }
            }, room=receiver_data['sid'])

            logging.info(f'Bump between {sender_id} and {receiver_id} ({distance:.1f}m)')

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    print("Server starting on port 10000...")
    socketio.run(app, host='0.0.0.0', port=10000)