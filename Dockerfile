FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV GODOT_VERSION=4.2.2

RUN apt-get update && apt-get install -y \
    wget unzip ca-certificates libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 \
    libgl1-mesa-glx libglu1-mesa && rm -rf /var/lib/apt/lists/*

RUN wget -q https://downloads.tuxfamily.org/godotengine/${GODOT_VERSION}/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip \
    && unzip -q Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip \
    && mv Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot

WORKDIR /app
COPY . .

CMD ["godot", "--headless", "--path", ".", "--script", "res://scripts/physics_test_runner.gd"]
