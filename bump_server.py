from flask import Flask, jsonify, request
from flask_socketio import SocketIO, emit
from datetime import datetime
from geopy.distance import geodesic
import logging
#import eventlet

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your_secret_key_here'
socketio = SocketIO(app, cors_allowed_origins="*")
#eventlet.monkey_patch()

# Хранилище данных
users = {}  # {user_id: {'sid': sid, 'position': (lat, lng)}}
recent_bumps = {}  # {bump_id: bump_data}
bump_counter = 0

@app.route('/')
def dashboard():
    """Простой веб-интерфейс для просмотра событий"""
    bumps = list(recent_bumps.values())
    return f"""
    <h1>Bump Events Monitoring</h1>
    <p>Connected users: {len(users)}</p>
    <p>Total bump events: {len(bumps)}</p>
    <h2>Recent Events:</h2>
    <ul>
        {"".join(
            f"<li><strong>{b['sender_id']}</strong> at {b['timestamp']}<br>"
            f"Location: {b['location']['lat']:.6f}, {b['location']['lng']:.6f}<br>"
            f"Accuracy: {b['accuracy']}m, Speed: {b['speed']}m/s</li>"
            for b in sorted(bumps, key=lambda x: x['timestamp'], reverse=True)[:20]
        )}
    </ul>
    <p><a href="/bumps">View all as JSON</a></p>
    """

@app.route('/bumps', methods=['GET'])
def get_all_bumps():
    """API endpoint для получения всех событий"""
    return jsonify({
        'status': 'success',
        'count': len(recent_bumps),
        'bumps': list(recent_bumps.values())
    })

@socketio.on('connect')
def handle_connect(auth):
    """Обработчик подключения клиента"""
    logging.info(f'Client connected: {request.sid}')

@socketio.on('disconnect')
def handle_disconnect():
    """Обработчик отключения клиента"""
    for user_id, user_data in list(users.items()):
        if user_data['sid'] == request.sid:
            logging.info(f'User disconnected: {user_id}')
            del users[user_id]
            break

@socketio.on('register')
def handle_register(user_id):
    """Регистрация пользователя"""
    if user_id not in users:
        users[user_id] = {
            'sid': request.sid,
            'position': None
        }
        logging.info(f'User registered: {user_id}')
        emit('registration_success', {'status': 'OK'})

@socketio.on('bump')
def handle_bump(data):
    """Обработчик события тряски"""
    global bump_counter
    
    # Создаем уникальный ID для события
    bump_id = f"bump_{bump_counter}"
    bump_counter += 1
    
    # Основные данные
    sender_id = data.get('senderId')
    timestamp = data.get('timestamp', datetime.now().isoformat())
    
    # Данные местоположения
    location_data = {
        'lat': data.get('lat'),
        'lng': data.get('lng')
    }
    
    # Метаданные
    accuracy = data.get('accuracy')
    speed = data.get('speed')
    
    # Сохраняем событие
    recent_bumps[bump_id] = {
        'bump_id': bump_id,
        'sender_id': sender_id,
        'timestamp': timestamp,
        'location': location_data,
        'accuracy': accuracy,
        'speed': speed,
        'server_received_at': datetime.now().isoformat()
    }
    
    # Логируем событие
    log_message = (
        f"New bump event #{bump_counter} from {sender_id}\n"
        f"  Time: {timestamp}\n"
        f"  Location: {location_data['lat']:.6f}, {location_data['lng']:.6f}\n"
        f"  Accuracy: {accuracy}m, Speed: {speed}m/s\n"
        f"  Server time: {recent_bumps[bump_id]['server_received_at']}"
    )
    logging.info(log_message)
    print(log_message)
    
    # Обновляем позицию пользователя
    if sender_id in users:
        users[sender_id]['position'] = (location_data['lat'], location_data['lng'])
        
        # Поиск ближайших пользователей (радиус 50 метров)
        for receiver_id, receiver_data in users.items():
            if receiver_id != sender_id and receiver_data['position']:
                distance = geodesic(
                    (location_data['lat'], location_data['lng']),
                    receiver_data['position']
                ).meters
                
                if distance < 50:
                    # Отправляем событие получателю
                    emit('bump_event', {
                        'event_type': 'bump',
                        'bump_id': bump_id,
                        'sender_id': sender_id,
                        'timestamp': timestamp,
                        'location': location_data,
                        'distance': distance
                    }, room=receiver_data['sid'])
                    
                    # Отправляем подтверждение отправителю
                    emit('bump_event', {
                        'event_type': 'bump_ack',
                        'bump_id': bump_id,
                        'receiver_id': receiver_id,
                        'timestamp': timestamp,
                        'location': {
                            'lat': receiver_data['position'][0],
                            'lng': receiver_data['position'][1]
                        },
                        'distance': distance
                    }, room=users[sender_id]['sid'])
                    
                    logging.info(f'Bump between {sender_id} and {receiver_id} (distance: {distance:.1f}m)')

if __name__ == '__main__':
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    
    print("Starting server...")
    print(f"Dashboard available at: http://localhost:5000")
    print(f"API endpoint: http://localhost:5000/bumps")
    
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)
    #socketio.run(app, host='0.0.0.0', port=10000)