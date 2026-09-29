from models import User, engine
from sqlalchemy.orm import sessionmaker
from pydantic import BaseModel
Session = sessionmaker(bind= engine)
session = Session()
user = User(email="arjun.1251080046@vit.edu",password_hash = "arjun@05",User_role = "guardian")
session.add(user)
session.commit()