FROM python:3.12-slim
WORKDIR /app
COPY identity_backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt \
    && useradd --create-home --uid 10001 gaminghub
COPY identity_backend /app/identity_backend
COPY server /app/server
COPY data /app/data
COPY content/qaadet_el_sohab /app/content/qaadet_el_sohab
COPY assets /app/assets
ENV PYTHONUNBUFFERED=1 DUEL_MODERATION_DB=/tmp/gaminghub-test-moderation.sqlite
USER gaminghub
EXPOSE 10000
CMD ["sh", "-c", "exec uvicorn identity_backend.integrated_app:app --host 0.0.0.0 --port ${PORT:-10000} --workers 1"]
