#!/bin/bash

# --- CẤU HÌNH TẢI MODEL TỐC ĐỘ CAO VỚI ARIA2 ---
# Tệp này hỗ trợ HF_TOKEN nếu được truyền vào qua biến môi trường.
# Aria2 sẽ sử dụng header Authorization nếu token tồn tại.

function fast_download() {
    local url=$1
    local dir=$2
    local filename=$3
    
    mkdir -p "$dir"
    
    if [ ! -f "$dir/$filename" ]; then
        echo "📥 Đang tải $filename vào $dir..."
        
        # Kiểm tra nếu có HF_TOKEN thì thêm header vào aria2c
        if [ -n "$HF_TOKEN" ]; then
            aria2c -x 16 -s 16 -k 1M --header="Authorization: Bearer $HF_TOKEN" "$url" -d "$dir" -o "$filename"
        else
            aria2c -x 16 -s 16 -k 1M "$url" -d "$dir" -o "$filename"
        fi
    else
        echo "✅ $filename đã tồn tại, bỏ qua bước tải."
    fi
}

echo "🚀 Bắt đầu quá trình Provisioning (Cài đặt Model AI)..."

# 1. TẢI FLUX.1 SCHNELL (BẢN GGUF TỐI ƯU VRAM)
fast_download \
    "https://huggingface.co/city96/FLUX.1-schnell-gguf/resolve/main/flux1-schnell-Q8_0.gguf" \
    "/workspace/ComfyUI/models/unet" \
    "flux1-schnell-Q8_0.gguf"

# 2. TẢI WAN 2.1 I2V 720P (BẢN GGUF ĐIỆN ẢNH)
fast_download \
    "https://huggingface.co/city96/Wan2.1-I2V-14B-720P-GGUF/resolve/main/wan2.1-i2v-14b-720p-Q8_0.gguf" \
    "/workspace/ComfyUI/models/checkpoints" \
    "wan2.1-i2v-14b-720p-Q8_0.gguf"

# 3. TẢI VAE CHUYÊN DỤNG CHO WAN VIDEO
fast_download \
    "https://huggingface.co/Wan-Video/Wan2.1-I2V-14B-720P/resolve/main/wan_vae.safetensors" \
    "/workspace/ComfyUI/models/vae" \
    "wan_vae.safetensors"

# 4. TẢI CLIP MODELS (Sử dụng FP8 để tiết kiệm VRAM)
fast_download \
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" \
    "/workspace/ComfyUI/models/clip" \
    "t5xxl_fp8_e4m3fn.safetensors"

echo "✅ Hoàn tất tải Model. Hệ thống ai-dock đang khởi động ComfyUI..."