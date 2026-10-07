# Picked up automatically by `gunicorn server:app` (Render start command; gunicorn binds to $PORT itself).
# preload_app imports server.py once in the master process, so every worker shares the same
# fallback SECRET_KEY when the env var is unset (otherwise logins would randomly fail).
preload_app = True
