"""
AKS Demo Application - Simple Flask API
"""
from flask import Flask, jsonify, request
import os
import socket
from datetime import datetime

app = Flask(__name__)

# 환경변수에서 설정 읽기
APP_VERSION = os.getenv('APP_VERSION', '1.0.0')
ENVIRONMENT = os.getenv('ENVIRONMENT', 'development')

@app.route('/')
def home():
    """메인 페이지"""
    return jsonify({
        'message': 'Welcome to AKS Demo Application!',
        'version': APP_VERSION,
        'environment': ENVIRONMENT
    })

@app.route('/health')
def health():
    """헬스체크 엔드포인트 - Kubernetes Probe용"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/ready')
def ready():
    """준비 상태 체크 - Kubernetes Readiness Probe용"""
    return jsonify({
        'status': 'ready',
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/info')
def info():
    """Pod 정보 표시 - AKS에서 어느 Pod가 응답하는지 확인용"""
    return jsonify({
        'hostname': socket.gethostname(),
        'ip_address': socket.gethostbyname(socket.gethostname()),
        'version': APP_VERSION,
        'environment': ENVIRONMENT,
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/api/items', methods=['GET'])
def get_items():
    """샘플 API - 아이템 목록 조회"""
    items = [
        {'id': 1, 'name': 'Item 1', 'description': 'First item'},
        {'id': 2, 'name': 'Item 2', 'description': 'Second item'},
        {'id': 3, 'name': 'Item 3', 'description': 'Third item'}
    ]
    return jsonify({'items': items, 'count': len(items)})

@app.route('/api/items', methods=['POST'])
def create_item():
    """샘플 API - 아이템 생성"""
    data = request.get_json()
    if not data or 'name' not in data:
        return jsonify({'error': 'Name is required'}), 400

    new_item = {
        'id': 4,
        'name': data['name'],
        'description': data.get('description', '')
    }
    return jsonify({'item': new_item, 'message': 'Item created successfully'}), 201

@app.route('/api/echo', methods=['POST'])
def echo():
    """에코 API - 받은 데이터 그대로 반환"""
    data = request.get_json()
    return jsonify({
        'received': data,
        'processed_by': socket.gethostname(),
        'timestamp': datetime.utcnow().isoformat()
    })

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    debug = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'
    app.run(host='0.0.0.0', port=port, debug=debug)
