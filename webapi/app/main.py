from fastapi import FastAPI
from fastapi import Query, Path
from typing import Optional, List
import subprocess
import sys
import json
from pydantic import BaseModel, Field
from enum import Enum
import uvicorn
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-d', '--db', required=True)
parser.add_argument('-b', '--bind', default='0.0.0.0')
parser.add_argument('-p', '--port', type=int, default=8000)
args = parser.parse_args()
print(args)
ezdb = args.db

#print(ezdb)
#print(args)

app = FastAPI()

class OptWith(str, Enum):
    none = "none"
    parent = "parent" 
    children = "children"
    ancestors = "ancestors"
    descendants = "descendants"

class GffRecord(BaseModel):
    seqid: str = Field(title="seqid", descripion="GFF3 column 1: sequence ID", example="NC_002528.1")
    source: str = Field(title="source", descripion="GFF3 column 2: algorithm or operating procedure", example="Refseq")
    type: str
    start: int
    end: int
    score: Optional[str] = None
    strand: str
    phase: Optional[int] = None
    line_num: int
    id: str
    parent_id: Optional[str] = None
    attributes: dict

class GffRecords(BaseModel):
    gff_records: List[GffRecord]

@app.get("/view/{query}", response_model=GffRecords)
def view(
    query: str = Path(..., example="NC_002528.1"),
    w: OptWith = Query("none", description="with"),
    t: Optional[str] = Query(None, description="type", example="gene")
    ):
    return json.loads(run_ezgff(query, w, t))

def run_ezgff(query, w, t):
    cmd = ["ezgff", "view", ezdb, query, "-f", "json", "-w", w]
    if t:
        cmd.extend(["-t", t])
    print(cmd)
    proc = subprocess.run(cmd, stdout=subprocess.PIPE)
    res = proc.stdout
    print(res)
    return res


if __name__ == "__main__":
    uvicorn.run(app, host=args.bind, port=args.port)