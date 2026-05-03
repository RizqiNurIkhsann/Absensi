import cv2
import numpy as np
import face_recognition
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from pydantic import BaseModel
import json

app = FastAPI(title="Face Recognition AI Service")

class CompareRequest(BaseModel):
    db_encoding: str  # JSON list string of the 128-d encoding from Laravel

@app.post("/encode-face")
async def encode_face(image: UploadFile = File(...)):
    if not image.filename:
        raise HTTPException(status_code=400, detail="No file provided")

    # Read image into numpy array
    contents = await image.read()
    nparr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if img is None:
        raise HTTPException(status_code=400, detail="Invalid image encoding")

    # Convert BGR (OpenCV) to RGB (face_recognition)
    rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # Detect faces
    face_locations = face_recognition.face_locations(rgb_img)

    if len(face_locations) == 0:
        raise HTTPException(status_code=400, detail="Wajah tidak ditemukan di foto.")
    
    if len(face_locations) > 1:
        raise HTTPException(status_code=400, detail="Terdeteksi lebih dari 1 wajah. Harap gunakan foto sendirian.")

    # Get encoding for the single face
    face_encodings = face_recognition.face_encodings(rgb_img, face_locations)
    
    if len(face_encodings) == 0:
        raise HTTPException(status_code=400, detail="Gagal mengekstrak fitur wajah.")

    encoding = face_encodings[0].tolist() # Convert numpy array to Python list

    return {
        "success": True,
        "message": "Wajah berhasil dipindai dan dikonversi.",
        "encoding": encoding
    }

@app.post("/compare-face")
async def compare_face(image: UploadFile = File(...), db_encoding: str = Form(...)):
    # 1. Parse existing encoding from DB
    try:
        known_encoding = np.array(json.loads(db_encoding))
    except Exception as e:
        raise HTTPException(status_code=400, detail="Format db_encoding invalid.")

    # 2. Extract encoding from uploaded image
    contents = await image.read()
    nparr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if img is None:
        raise HTTPException(status_code=400, detail="Bentuk foto tidak dapat dibaca.")

    rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    face_locations = face_recognition.face_locations(rgb_img)

    if len(face_locations) == 0:
        return {"match": False, "success": False, "message": "Tidak ada wajah di frame!"}
    
    if len(face_locations) > 1:
        return {"match": False, "success": False, "message": "Ada lebih dari 1 wajah terdeteksi!"}

    uploaded_encoding = face_recognition.face_encodings(rgb_img, face_locations)[0]

    # 3. Calculate Distance
    # default threshold is 0.6. Lower is stricter.
    distances = face_recognition.face_distance([known_encoding], uploaded_encoding)
    distance = float(distances[0])
    
    is_match = distance <= 0.6  # True if same person
    # Optional confidence conversion (distance 0 = 100%, distance 0.6 = arbitrary %)
    confidence = max(0.0, 1.0 - distance)

    return {
        "success": True,
        "match": is_match,
        "confidence": round(confidence, 4),
        "distance": round(distance, 4)
    }

if __name__ == "__main__":
    import uvicorn
    # Jalankan server
    uvicorn.run(app, host="127.0.0.1", port=5000)
