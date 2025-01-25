from kagiapi import KagiClient
import requests

def search(api_key: str, query: str, limit: int=10):
    kagi = KagiClient(api_key)
    results = kagi.search(query, limit=limit)
    return results

def summarize(api_key:str, url:str, summary_type:str="summary", engine:str="muriel"):
    base_url = 'https://kagi.com/api/v0/summarize'
    params = {
        "url": "https://www.youtube.com/watch?v=ZSRHeXYDLko",
        "summary_type": "summary",
        "engine": "muriel"
    }
    headers = {'Authorization': f'Bot {api_key}'}
    response = requests.get(base_url, headers=headers, params=params)
    return response.json()
