import json
from aiohttp import web

from yandexfreetranslate import YandexFreeTranslate

async def handle(request):
    headers = {"Content-Type": "application/json; charset=utf-8"}

    if request.method not in ['POST', 'GET']:
        return web.Response(headers=headers, text=json.dumps({"success": False, "error": "Method not allowed"}))

    source = target = text = None
    if request.method == "POST":
        if 'json' in request.headers.get("Content-Type").lower():
            try:
                data = await request.json()
            except:
                return web.Response(code=404, headers=headers, text=json.dumps({"success": False, "error": "You're specified invalid JSON"}))
            
            source = data['source']
            target = data['target']
            text = data['text']
        else:
            data = await request.post()
            source = data.get('source', None)
            target = data.get('target', None)
            text = data.get('text', None)

    elif request.method == 'GET':
        data = request.query
        source = data.get('source', None)
        target = data.get('target', None)
        text = data.get('text', None)

    if 'source' in data and 'target' in data and 'text' in data:
        yt = YandexFreeTranslate("ios")
        return web.Response(headers=headers, text=json.dumps({"success": True, "text": yt.translate(source=source, target=target, text=text)}))
    else:
        return web.Response(code=404, headers=headers, text=json.dumps({"success": False, "error": "You're specified invalid data"}))

app = web.Application()
app.router.add_route('*', '/', handle)

if __name__ == "__main__":
    web.run_app(app, host='127.0.0.1', port=9550)