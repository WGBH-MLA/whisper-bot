FROM arm64v8/debian:stable-slim
RUN apt update && apt install -y git ffmpeg python3 python3-pip
RUN pip install -U pip
RUN pip install git+https://github.com/openai/whisper.git
