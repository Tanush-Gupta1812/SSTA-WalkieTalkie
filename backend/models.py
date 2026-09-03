from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

class CreateGroupRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100, description="Group name")

class GroupResponse(BaseModel):
    id: str
    name: str
    join_token: str
    member_count: int = 0
    created_at: Optional[str] = None

class JoinGroupRequest(BaseModel):
    join_token: str = Field(..., min_length=4, max_length=50)
    user_id: str = Field(..., min_length=1)
    display_name: str = Field(..., min_length=1, max_length=50)

class MemberResponse(BaseModel):
    user_id: str
    display_name: str
    is_online: bool = False
    joined_at: Optional[str] = None

class LeaveGroupResponse(BaseModel):
    status: str
    group_id: str
    user_id: str
