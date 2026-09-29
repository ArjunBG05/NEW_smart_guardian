from datetime import datetime,timezone,timedelta
from jose import jwt ,JWTError
from typing import Any
from dotenv import load_dotenv
import os 
load_dotenv()
class JWTservice:
    Secret = os.getenv("JWT_SECRET")
    Algorithm = "HS256"
    Expiry_Time_inmins = 5

    def encode(self,user_id:str) -> str:
        data = {"sub":str(user_id)}

        expire = datetime.now(timezone.utc) + timedelta(minutes=JWTservice.Expiry_Time_inmins)

        data.update({"exp":expire})
        return jwt.encode(data,JWTservice.Secret,algorithm=JWTservice.Algorithm)


    def decode(self,token :str) -> dict[str,Any] | None:
        try :
            return jwt.decode(token,JWTservice.Secret,algorithms=[JWTservice.Algorithm])

        except JWTError as ex:
            print(f"Exception in JWT decode :{str(ex)}")
            return None