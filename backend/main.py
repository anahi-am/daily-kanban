from fastapi import FastAPI

app = FastAPI(title="Daily Kanban API")


@app.get("/")
def root():
    return {"message": "Daily Kanban API"}
