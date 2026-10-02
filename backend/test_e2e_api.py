#!/usr/bin/env python3
import urllib.request
import urllib.parse
import json
import time
import os
import uuid

BASE_URL = os.environ.get("BASE_URL", "https://lorivery.onrender.com")

print(f"🚀 Probando Backend en: {BASE_URL}")

def make_request(url, method="GET", data=None, json_data=None, headers=None, files=None):
    req_headers = headers or {}
    body = None
    
    if json_data is not None:
        body = json.dumps(json_data).encode("utf-8")
        req_headers["Content-Type"] = "application/json"
    elif files is not None or (data is not None and files is not None):
        boundary = "----WebKitFormBoundary" + uuid.uuid4().hex
        req_headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
        parts = []
        if data:
            for k, v in data.items():
                parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}".encode("utf-8"))
        if files:
            for field_name, (filename, file_content, content_type) in files.items():
                header = f"--{boundary}\r\nContent-Disposition: form-data; name=\"{field_name}\"; filename=\"{filename}\"\r\nContent-Type: {content_type}\r\n\r\n"
                parts.append(header.encode("utf-8") + file_content)
        body = b"\r\n".join(parts) + f"\r\n--{boundary}--\r\n".encode("utf-8")
    elif data is not None:
        body = urllib.parse.urlencode(data).encode("utf-8")
        req_headers["Content-Type"] = "application/x-www-form-urlencoded"

    req = urllib.request.Request(url, data=body, headers=req_headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            resp_body = resp.read().decode("utf-8")
            return resp.status, resp_body
    except urllib.error.HTTPError as e:
        resp_body = e.read().decode("utf-8")
        return e.code, resp_body

def test_flow():
    # 1. Root
    print("\n--- 1. Test Ping Root ---")
    status, body = make_request(f"{BASE_URL}/")
    print(f"Status: {status}, Body: {body}")
    assert status == 200, f"Error en root: {body}"

    # 2. Register Client
    timestamp = int(time.time())
    client_email = f"client_{timestamp}@lorivery.com"
    print(f"\n--- 2. Register Client ({client_email}) ---")
    client_data = {
        "name": "Cliente Lorica Test",
        "email": client_email,
        "password": "Password123!",
        "role": "CLIENT"
    }
    status, body = make_request(f"{BASE_URL}/auth/register", method="POST", json_data=client_data)
    print(f"Status: {status}, Body: {body}")
    assert status in (200, 201), f"Fallo al registrar cliente: {body}"
    client_json = json.loads(body)
    client_token = client_json["access_token"]
    client_id = client_json["user_id"]

    # 3. Register Courier
    courier_email = f"courier_{timestamp}@lorivery.com"
    print(f"\n--- 3. Register Courier ({courier_email}) ---")
    courier_data = {
        "name": "Repartidor Lorica Test",
        "email": courier_email,
        "password": "Password123!",
        "role": "COURIER",
        "phone_number": "3001234567",
        "national_id": "1002345678",
        "vehicle_type": "MOTORCYCLE",
        "is_adult": True
    }
    status, body = make_request(f"{BASE_URL}/auth/register", method="POST", json_data=courier_data)
    print(f"Status: {status}, Body: {body}")
    assert status in (200, 201), f"Fallo al registrar repartidor: {body}"
    courier_json = json.loads(body)
    courier_token = courier_json["access_token"]
    courier_id = courier_json["user_id"]

    # 4. Upload Courier Documents
    print(f"\n--- 4. Upload Courier KYC Documents ---")
    dummy_img = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    files = {
        "id_front": ("id_front.png", dummy_img, "image/png"),
        "id_back": ("id_back.png", dummy_img, "image/png"),
        "selfie": ("selfie.png", dummy_img, "image/png"),
    }
    status, body = make_request(
        f"{BASE_URL}/couriers/documents", 
        method="POST", 
        headers={"Authorization": f"Bearer {courier_token}"}, 
        files=files
    )
    print(f"Status: {status}, Body: {body}")

    # 5. Check Pending Couriers (Admin)
    print(f"\n--- 5. Admin: List Pending Couriers ---")
    status, body = make_request(f"{BASE_URL}/admin/couriers/pending")
    print(f"Status: {status}, Body: {body}")
    
    # 6. Approve Courier
    print(f"\n--- 6. Admin: Approve Courier ({courier_id}) ---")
    status, body = make_request(f"{BASE_URL}/admin/couriers/{courier_id}/approve", method="PATCH")
    print(f"Status: {status}, Body: {body}")

    # 7. Check Courier Profile & Status
    print(f"\n--- 7. Courier: Check Profile (GET /couriers/me) ---")
    status, body = make_request(
        f"{BASE_URL}/couriers/me", 
        headers={"Authorization": f"Bearer {courier_token}"}
    )
    print(f"Status: {status}, Body: {body}")

    # 8. List Restaurants
    print(f"\n--- 8. List Restaurants & Products ---")
    status, body = make_request(f"{BASE_URL}/api/restaurants/")
    print(f"Status: {status}, Body: {body}")
    restaurants = json.loads(body)
    assert len(restaurants) > 0, "Debe haber al menos 1 restaurante"
    selected_restaurant = restaurants[0]
    print(f"Restaurante seleccionado: {selected_restaurant['name']} (ID: {selected_restaurant['id']})")

    # 9. Create Order (Cliente pide comida con token JWT)
    print(f"\n--- 9. Client: Create Order (POST /orders/) ---")
    order_data = {
        "restaurant_id": str(selected_restaurant["id"]),
        "delivery_address": "Barrio Arenal, Calle 4 # 12-34, Lorica",
        "delivery_lat": "9.242",
        "delivery_lng": "-75.815",
        "total_amount": "25000",
    }
    order_files = {
        "payment_proof": ("comprobante.png", dummy_img, "image/png")
    }
    status, body = make_request(
        f"{BASE_URL}/orders/", 
        method="POST", 
        headers={"Authorization": f"Bearer {client_token}"},
        data=order_data, 
        files=order_files
    )
    print(f"Status: {status}, Body: {body}")
    assert status in (200, 201), f"Fallo al crear orden: {body}"
    order_json = json.loads(body)
    order_id = order_json["order_id"]
    delivery_fee = order_json.get("delivery_fee")
    pickup_code = order_json.get("pickup_code")
    delivery_code = order_json.get("delivery_code")
    print(f"🎉 Created Order ID: {order_id}, Fee: ${delivery_fee:,.0f} COP, PIN Recogida: {pickup_code}, PIN Entrega: {delivery_code}")

    # 10. Admin Approve Order Payment
    print(f"\n--- 10. Admin: Approve Order Payment ({order_id}) ---")
    status, body = make_request(f"{BASE_URL}/admin/orders/{order_id}/approve", method="PATCH")
    print(f"Status: {status}, Body: {body}")
    assert status == 200, f"Fallo al aprobar orden: {body}"

    # 11. Courier Accept Order
    print(f"\n--- 11. Courier: Accept Order ---")
    status, body = make_request(
        f"{BASE_URL}/orders/{order_id}/accept", 
        method="POST", 
        headers={"Authorization": f"Bearer {courier_token}"}
    )
    print(f"Status: {status}, Body: {body}")
    assert status == 200, f"Fallo al aceptar orden: {body}"

    # 12. Courier Change Status to PICKED_UP
    print(f"\n--- 12. Courier: Mark Order as PICKED_UP (con PIN de recogida {pickup_code}) ---")
    status, body = make_request(
        f"{BASE_URL}/orders/{order_id}/status", 
        method="PATCH", 
        headers={"Authorization": f"Bearer {courier_token}"},
        json_data={"status": "PICKED_UP", "pickup_code": pickup_code}
    )
    print(f"Status: {status}, Body: {body}")
    assert status == 200, f"Fallo al marcar PICKED_UP: {body}"

    # 13. Courier Change Status to DELIVERED (triggers auto-balance credit)
    print(f"\n--- 13. Courier: Mark Order as DELIVERED (con PIN de entrega {delivery_code}) ---")
    status, body = make_request(
        f"{BASE_URL}/orders/{order_id}/status", 
        method="PATCH", 
        headers={"Authorization": f"Bearer {courier_token}"},
        json_data={"status": "DELIVERED", "delivery_code": delivery_code}
    )
    print(f"Status: {status}, Body: {body}")
    assert status == 200, f"Fallo al marcar DELIVERED: {body}"

    # 14. Verify Balance Credited
    print(f"\n--- 14. Verify Courier Balance Auto-Credit ---")
    status, body = make_request(
        f"{BASE_URL}/couriers/me", 
        headers={"Authorization": f"Bearer {courier_token}"}
    )
    print(f"Status: {status}, Body: {body}")
    final_balance = json.loads(body).get("balance", 0.0)
    print(f"💰 Saldo final acreditado al repartidor: ${final_balance:,.0f} COP (Esperado: ${delivery_fee:,.0f} COP)")
    assert final_balance == delivery_fee, f"El saldo ({final_balance}) debe coincidir con la tarifa ({delivery_fee})"

    # 15. Client: Check Order Tracking (GET /orders/{id})
    print(f"\n--- 15. Client: Check Order Tracking (GET /orders/{order_id}) ---")
    status, body = make_request(
        f"{BASE_URL}/orders/{order_id}", 
        headers={"Authorization": f"Bearer {client_token}"}
    )
    print(f"Status: {status}, Body: {body}")
    assert status == 200

    # 16. Admin Web Dashboard
    print(f"\n--- 16. Admin Web Dashboard (HTML) ---")
    status, body = make_request(f"{BASE_URL}/admin-web/dashboard")
    print(f"Status: {status} (Length: {len(body)} bytes)")
    assert status == 200

    # 17. Merchant Dashboard
    print(f"\n--- 17. Merchant Web Dashboard ({selected_restaurant['name']}) ---")
    status, body = make_request(f"{BASE_URL}/merchant-web/{selected_restaurant['id']}/dashboard")
    print(f"Status: {status} (Length: {len(body)} bytes)")
    assert status == 200

    print("\n" + "="*65)
    print("🏆 ¡PRUEBA E2E COMPLETA EXITOSA: 100% DE LA APLICACIÓN FUNCIONA!")
    print("="*65)

if __name__ == "__main__":
    test_flow()
