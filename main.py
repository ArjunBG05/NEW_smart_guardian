from fastapi import FastAPI

from auth import router as auth_router


app = FastAPI(
    title="Smart Guardian API",
    version="1.0.0"
)


app.include_router(auth_router)


@app.get("/")
def home():
    return {
        "message": "Smart Guardian API is running"
    }