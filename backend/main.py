from datetime import date, datetime
from typing import Optional

from bson import ObjectId
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from database import connect_db, close_db, get_db

app = FastAPI(title="Daily Kanban API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup():
    await connect_db()


@app.on_event("shutdown")
async def shutdown():
    await close_db()


# --- Models ---

class SubtaskModel(BaseModel):
    id: Optional[str] = None
    task_id: str
    content: str = ""


class TaskModel(BaseModel):
    id: Optional[str] = None
    title: str
    priority: str = "medium"
    status: str = "backlog"
    board_date: str
    subtasks: list[SubtaskModel] = []


class TaskCreate(BaseModel):
    title: str
    notes: str = ""
    status: str = "backlog"


class TaskWithSubtasksCreate(BaseModel):
    title: str
    notes: str = ""
    status: str = "backlog"
    subtasks: list[str] = []


class SubtaskCreate(BaseModel):
    task_id: str
    content: str = ""


class SubtaskUpdate(BaseModel):
    content: str


class StatusUpdate(BaseModel):
    status: str


# --- Helpers ---

def today_str() -> str:
    return date.today().isoformat()


def serialize_task(doc) -> dict:
    doc["id"] = str(doc.pop("_id"))
    doc["subtasks"] = [serialize_subtask(s) if "_id" in s else s for s in doc.get("subtasks", [])]
    return doc


def serialize_subtask(doc) -> dict:
    if isinstance(doc, dict) and "_id" in doc:
        doc["id"] = str(doc.pop("_id"))
    return doc


# --- Routes ---

@app.get("/")
def root():
    return {"message": "Daily Kanban API"}


@app.post("/rollover")
async def rollover():
    db = get_db()
    today = today_str()
    result = await db.tasks.update_many(
        {"board_date": {"$lt": today}, "status": {"$ne": "done"}},
        {"$set": {"board_date": today}},
    )
    return {"modified": result.modified_count}


@app.get("/tasks")
async def fetch_board():
    db = get_db()
    today = today_str()
    cursor = db.tasks.find({"board_date": today}).sort("created_at", 1)
    tasks = [serialize_task(doc) async for doc in cursor]
    return tasks


@app.post("/tasks")
async def add_task(body: TaskCreate):
    db = get_db()
    doc = {
        "title": body.title,
        "notes": body.notes,
        "status": body.status,
        "board_date": today_str(),
        "subtasks": [],
        "created_at": datetime.utcnow(),
    }
    result = await db.tasks.insert_one(doc)
    doc["_id"] = result.inserted_id
    return serialize_task(doc)


@app.post("/tasks/with-subtasks")
async def add_task_with_subtasks(body: TaskWithSubtasksCreate):
    db = get_db()
    subs = []
    for content in body.subtasks:
        subs.append({"_id": ObjectId(), "task_id": "", "content": content})
    doc = {
        "title": body.title,
        "notes": body.notes,
        "status": body.status,
        "board_date": today_str(),
        "subtasks": subs,
        "created_at": datetime.utcnow(),
    }
    result = await db.tasks.insert_one(doc)
    doc["_id"] = result.inserted_id
    return serialize_task(doc)


@app.delete("/tasks/{task_id}")
async def delete_task(task_id: str):
    db = get_db()
    result = await db.tasks.delete_one({"_id": ObjectId(task_id)})
    if result.deleted_count == 0:
        raise HTTPException(404, "Task not found")
    return {"deleted": True}


@app.patch("/tasks/{task_id}/status")
async def update_status(task_id: str, body: StatusUpdate):
    db = get_db()
    result = await db.tasks.update_one(
        {"_id": ObjectId(task_id)},
        {"$set": {"status": body.status}},
    )
    if result.matched_count == 0:
        raise HTTPException(404, "Task not found")
    return {"updated": True}


@app.post("/subtasks")
async def add_subtask(body: SubtaskCreate):
    db = get_db()
    sub_doc = {
        "_id": ObjectId(),
        "task_id": body.task_id,
        "content": body.content,
    }
    result = await db.tasks.update_one(
        {"_id": ObjectId(body.task_id)},
        {"$push": {"subtasks": sub_doc}},
    )
    if result.matched_count == 0:
        raise HTTPException(404, "Task not found")
    return serialize_subtask(sub_doc)


@app.patch("/subtasks/{subtask_id}")
async def update_subtask(subtask_id: str, body: SubtaskUpdate):
    db = get_db()
    result = await db.tasks.update_one(
        {"subtasks._id": ObjectId(subtask_id)},
        {"$set": {"subtasks.$.content": body.content}},
    )
    if result.matched_count == 0:
        raise HTTPException(404, "Subtask not found")
    return {"updated": True}


@app.delete("/subtasks/{subtask_id}")
async def delete_subtask(subtask_id: str):
    db = get_db()
    result = await db.tasks.update_one(
        {"subtasks._id": ObjectId(subtask_id)},
        {"$pull": {"subtasks": {"_id": ObjectId(subtask_id)}}},
    )
    if result.matched_count == 0:
        raise HTTPException(404, "Subtask not found")
    return {"deleted": True}
