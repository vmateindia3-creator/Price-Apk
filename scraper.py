import os
import json
import firebase_admin
from firebase_admin import credentials, firestore

# GitHub Secret se key read karega
if "FIREBASE_KEY_JSON" in os.environ:
    cred_json = json.loads(os.environ["FIREBASE_KEY_JSON"])
    cred = credentials.Certificate(cred_json)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("Firebase connected successfully!")
