FROM python:3.10-slim
RUN apt update && apt install -y git ffmpeg
RUN pip install -U pip
RUN pip install git+https://github.com/openai/whisper.git
CMD whisper