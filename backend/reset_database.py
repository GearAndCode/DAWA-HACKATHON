import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.database import DB_PATH, engine, Base
from seed import seed

def reset():
    print(f"Resetting database at {DB_PATH}...")
    if os.path.exists(DB_PATH):
        try:
            os.remove(DB_PATH)
            print("Existing database removed.")
        except Exception as e:
            print(f"Could not remove database file directly: {e}. Dropping tables instead.")
            Base.metadata.drop_all(bind=engine)
    
    seed()
    print("Database reset and re-seeded successfully.")

if __name__ == "__main__":
    reset()
