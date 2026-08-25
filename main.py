from fastapi import FastAPI 
app = FastAPI()
@app.get("/")
def login_page():   
    return {"Backend is working!!"}       