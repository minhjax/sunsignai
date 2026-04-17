#!/bin/bash

# ==============================================================================
# HỆ THỐNG PROVISIONING SERVERLESS CHO VIDEO ADS CHUYÊN NGHIỆP (FULL STACK)
# Dự án: Sunsign AI - Video Engine (First -> Last Frame Workflow)
# ==============================================================================

COMFY_DIR=${COMFYUI_DIR:-"/sunspace"}
CUSTOM_NODES_DIR="$COMFY_DIR/custom_nodes"

echo "🚀 Bắt đầu cấu hình Video AI Engine (Kích hoạt Toàn bộ Hệ thống)..."
echo "📂 Thư mục gốc: $COMFY_DIR"

# --- HÀM TẢI MODEL TỐC ĐỘ CAO (CÓ CƠ CHẾ DỰ PHÒNG CHỐNG LỖI MẠNG) ---
function fast_download() {
    local url=$1
    local dir=$2
    local filename=$3
    mkdir -p "$dir"
    
    if [ ! -f "$dir/$filename" ]; then
        echo "📥 Đang tải $filename..."
        
        # Nếu có aria2, thử dùng để tăng tốc
        if command -v aria2c &> /dev/null; then
            aria2c -x 16 -s 16 -k 1M -c --auto-file-renaming=false "$url" -d "$dir" -o "$filename"
            
            # Nếu aria2c bị chặn/lỗi, tự động chuyển sang wget
            if [ $? -ne 0 ]; then
                echo "⚠️ aria2c bị chặn hoặc lỗi tải $filename. Đang chuyển sang wget..."
                rm -f "$dir/$filename" "$dir/$filename.aria2" # Dọn file lỗi
                wget -c "$url" -O "$dir/$filename"
            fi
        else
            # Nếu chưa cài aria2, dùng wget luôn
            echo "⚠️ Chưa có aria2c. Đang tải bằng wget..."
            wget -c "$url" -O "$dir/$filename"
        fi
    else
        echo "✅ $filename đã tồn tại."
    fi
}

# ==============================================================================
# PHẦN 1: HỆ SINH THÁI CUSTOM NODES (TẠO HÌNH + CHUYỂN ĐỘNG + HẬU KỲ + OVERLAY)
# ==============================================================================
mkdir -p "$CUSTOM_NODES_DIR"
cd "$CUSTOM_NODES_DIR"

echo "📦 Đang cài đặt thư viện Custom Nodes..."

declare -A NODES=(
    # --- Lõi hệ thống & Quản lý ---
    ["ComfyUI-Manager"]="https://github.com/ltdrdata/ComfyUI-Manager.git"
    ["rgthree-comfy"]="https://github.com/rgthree/rgthree-comfy.git"
    
    # --- Chuyển động (Video Core) ---
    ["ComfyUI-GGUF"]="https://github.com/city96/ComfyUI-GGUF.git"
    ["ComfyUI-WanVideoWrapper"]="https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
    ["ComfyUI-VideoHelperSuite"]="https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
    ["ComfyUI-Frame-Interpolation"]="https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git"
    
    # --- Điều khiển chi tiết (Sản phẩm & Khuôn mặt) ---
    ["ComfyUI_IPAdapter_plus"]="https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"
    ["ComfyUI-ControlNet-Aux"]="https://github.com/Fannovel16/comfyui_controlnet_aux.git"
    ["ComfyUI-Advanced-ControlNet"]="https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git"
    ["ComfyUI-segment-anything"]="https://github.com/storyicon/comfyui_segment_anything.git"
    
    # --- Xử lý Text Overlay & Composite Hậu kỳ ---
    ["ComfyUI-Impact-Pack"]="https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
    ["ComfyUI-LayerStyle"]="https://github.com/chflame163/ComfyUI-LayerStyle.git"
    ["ComfyUI_essentials"]="https://github.com/cubiq/ComfyUI_essentials.git"
    
    # --- Tiện ích mở rộng ---
    ["ComfyUI-KJNodes"]="https://github.com/Kijai/ComfyUI-KJNodes.git"
    ["ComfyUI-Easy-Use"]="https://github.com/yolain/ComfyUI-Easy-Use.git"
    ["ComfyUI_UltimateSDUpscale"]="https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
)

for node in "${!NODES[@]}"; do
    if [ ! -d "$node" ]; then
        git clone "${NODES[$node]}"
    fi
done

# Cài đặt Python Dependencies (Thêm cờ ignore để ẩn cảnh báo màu vàng)
echo "🔧 Đang cài đặt Python dependencies..."
for dir in */ ; do
    if [ -f "$dir/requirements.txt" ]; then
        pip install -r "$dir/requirements.txt" -q --root-user-action=ignore
    fi
done

# Cài đặt thư viện hệ thống cần thiết (Bổ sung aria2, wget, unzip)
apt-get update -y && apt-get install -y aria2 wget unzip git ffmpeg libsm6 libxext6 fonts-liberation fontconfig

# ==============================================================================
# PHẦN 2: TẢI MODEL CỐT LÕI (WAN, FLUX, VAE, CLIP)
# ==============================================================================
cd "$COMFY_DIR"
echo "🧠 Đang tải AI Models Cốt lõi..."

fast_download "https://huggingface.co/city96/Wan2.1-I2V-14B-720P-GGUF/resolve/main/wan2.1-i2v-14b-720p-Q8_0.gguf" "$COMFY_DIR/models/unet" "wan2.1-i2v-14b-720p-Q8_0.gguf"
fast_download "https://huggingface.co/Wan-Video/Wan2.1-I2V-14B-720P/resolve/main/wan_vae.safetensors" "$COMFY_DIR/models/vae" "wan_vae.safetensors"
fast_download "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" "$COMFY_DIR/models/clip" "t5xxl_fp8_e4m3fn.safetensors"
fast_download "https://huggingface.co/city96/FLUX.1-schnell-gguf/resolve/main/flux1-schnell-Q8_0.gguf" "$COMFY_DIR/models/unet" "flux1-schnell-Q8_0.gguf"

# ==============================================================================
# PHẦN 3: TẢI MODEL ĐIỀU KHIỂN & TÁCH NỀN (IPADAPTER, CONTROLNET, SAM, FACEID)
# ==============================================================================
echo "🎨 Đang tải các Model Điều khiển Sản phẩm & Thương hiệu..."

# IPAdapter Core
fast_download "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors" "$COMFY_DIR/models/clip_vision" "clip_vision_h.safetensors"
fast_download "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors" "$COMFY_DIR/models/ipadapter" "ip-adapter-plus_sdxl_vit-h.safetensors"

# Bộ xử lý khuôn mặt (Insightface / FaceID)
fast_download "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt" "$COMFY_DIR/models/ultralytics/bbox" "face_yolov8m.pt"
fast_download "https://github.com/deepinsight/insightface/releases/download/v0.7/antelopev2.zip" "$COMFY_DIR/models/insightface" "antelopev2.zip"
if [ -f "$COMFY_DIR/models/insightface/antelopev2.zip" ]; then
    echo "📦 Đang giải nén thư viện nhận diện khuôn mặt (antelopev2)..."
    unzip -q -o "$COMFY_DIR/models/insightface/antelopev2.zip" -d "$COMFY_DIR/models/insightface/models/antelopev2"
    rm "$COMFY_DIR/models/insightface/antelopev2.zip"
fi

# Tách nền tự động (Segment Anything)
fast_download "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" "$COMFY_DIR/models/sams" "sam_vit_b_01ec64.pth"

# ControlNet SDXL (Depth, Canny, OpenPose)
fast_download "https://huggingface.co/diffusers/controlnet-depth-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors" "$COMFY_DIR/models/controlnet" "controlnet_depth_sdxl.safetensors"
fast_download "https://huggingface.co/diffusers/controlnet-canny-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors" "$COMFY_DIR/models/controlnet" "controlnet_canny_sdxl.safetensors"
fast_download "https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors" "$COMFY_DIR/models/controlnet" "OpenPoseXL2.safetensors"

# ==============================================================================
# PHẦN 4: TẢI MODEL HẬU KỲ (UPSCALER & FRAME INTERPOLATION)
# ==============================================================================
echo "✨ Đang tải Hậu Kỳ Models..."

fast_download "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth" "$COMFY_DIR/models/upscale_models" "4x-UltraSharp.pth"
VFI_DIR="$COMFY_DIR/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife"
fast_download "https://huggingface.co/styler00dollar/VSGAN-tensorrt-docker/resolve/main/models/rife47.pth" "$VFI_DIR" "rife47.pth"

# ==============================================================================
# PHẦN 5: CÀI ĐẶT FONT CHỮ THƯƠNG HIỆU & QUẢNG CÁO TỰ ĐỘNG
# ==============================================================================
echo "🔤 Đang cài đặt cấu trúc phông chữ từ GitHub (sunsignai)..."

FONT_DIR="/usr/share/fonts/truetype/sunsign_fonts"
mkdir -p "$FONT_DIR"

# Kéo repo GitHub về thư mục tạm
echo "   -> Đang tải dữ liệu từ GitHub..."
git clone --depth 1 https://github.com/minhjax/sunsignai.git /tmp/sunsignai_repo

# Copy toàn bộ thư mục fonts (bao gồm các thư mục con Antonio, Inter...) vào hệ thống
if [ -d "/tmp/sunsignai_repo/fonts" ]; then
    echo "   -> Đang cài đặt phông chữ vào hệ thống..."
    cp -r /tmp/sunsignai_repo/fonts/* "$FONT_DIR/"
    # Cập nhật cache font hệ thống
    fc-cache -f -v
else
    echo "⚠️ Không tìm thấy thư mục fonts trong repo."
fi

# Dọn dẹp rác
rm -rf /tmp/sunsignai_repo

echo "🎉 HOÀN TẤT PROVISIONING! Hệ thống Sunsign AI Engine đã sẵn sàng rực sáng."