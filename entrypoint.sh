#!/bin/bash

# --- CẤU HÌNH ĐƯỜNG DẪN ---
FLUX_MODEL_PATH="/app/models/unet/flux1-schnell-Q8_0.gguf"
WAN_MODEL_DIR="/app/models/checkpoints/Wan2.1-I2V-14B-720P-GGUF" # Thư mục cho Wan 2.1 [cite: 17]

echo "🚀 Bắt đầu kiểm tra tài nguyên hệ thống..."

# 1. KIỂM TRA & TẢI FLUX 1 [SCHNELL] GGUF [cite: 13]
if [ ! -f "$FLUX_MODEL_PATH" ]; then
    echo "📥 Đang tải Flux 1 [schnell] Q8_0 GGUF vào /models/unet/..." [cite: 14]
    huggingface-cli download city96/FLUX.1-schnell-gguf flux1-schnell-Q8_0.gguf --local-dir /app/models/unet/
else
    echo "✅ Flux 1 [schnell] đã sẵn sàng."
fi

# 2. KIỂM TRA & TẢI WAN 2.1 720P (Bản I2V cho Cinema Video) [cite: 16, 17]
# Lưu ý: Chúng ta dùng bản Quantized (GGUF) để chạy mượt trên 24GB VRAM của RTX 4090
if [ ! -d "$WAN_MODEL_DIR" ]; then
    echo "📥 Đang tải Wan 2.1 I2V 720p vào /models/checkpoints/..." [cite: 17]
    # Tải bản I2V 14B Quantized để đảm bảo render < 1 phút [cite: 16]
    huggingface-cli download Wan-Video/Wan2.1-I2V-14B-720P-GGUF --local-dir "$WAN_MODEL_DIR"
else
    echo "✅ Wan 2.1 720p đã sẵn sàng."
fi

# 3. TẢI CÁC THÀNH PHẦN BỔ TRỢ (VAE, CLIP) [cite: 14]
if [ ! -f "/app/models/vae/ae.safetensors" ]; then
    echo "📥 Đang tải VAE cho Flux..."
    huggingface-cli download black-forest-labs/FLUX.1-schnell ae.safetensors --local-dir /app/models/vae/
fi

# --- KHỞI ĐỘNG COMFYUI ---
echo "🎨 Tất cả model đã sẵn sàng. Khởi động ComfyUI Engine..."
# Sử dụng --highvram và --listen để tối ưu cho API Mode [cite: 23]
python main.py --listen 0.0.0.0 --port 8188 --highvram