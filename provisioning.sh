#!/bin/bash

# ==============================================================================
# HỆ THỐNG PROVISIONING SERVERLESS CHO VIDEO ADS CHUYÊN NGHIỆP (ULTIMATE BUNDLE)
# ==============================================================================

COMFY_DIR=${COMFYUI_DIR:-"/workspace/ComfyUI"}
CUSTOM_NODES_DIR="$COMFY_DIR/custom_nodes"

echo "🚀 Bắt đầu cấu hình Video AI Engine (Kích hoạt Post-Production)..."
echo "📂 Thư mục gốc: $COMFY_DIR"

# --- HÀM TẢI MODEL TỐC ĐỘ CAO ---
function fast_download() {
    local url=$1
    local dir=$2
    local filename=$3
    mkdir -p "$dir"
    if [ ! -f "$dir/$filename" ]; then
        echo "📥 Đang tải $filename..."
        aria2c -x 16 -s 16 -k 1M -c --auto-file-renaming=false "$url" -d "$dir" -o "$filename"
    else
        echo "✅ $filename đã tồn tại."
    fi
}

# ==============================================================================
# PHẦN 1: HỆ SINH THÁI CUSTOM NODES (TẠO HÌNH + CHUYỂN ĐỘNG + HẬU KỲ)
# ==============================================================================
mkdir -p "$CUSTOM_NODES_DIR"
cd "$CUSTOM_NODES_DIR"

echo "📦 Đang cài đặt thư viện Custom Nodes toàn diện..."

declare -A NODES=(
    # Nhóm Core & Render Video
    ["ComfyUI-Manager"]="https://github.com/ltdrdata/ComfyUI-Manager.git"
    ["ComfyUI-GGUF"]="https://github.com/city96/ComfyUI-GGUF.git"
    ["ComfyUI-WanVideoWrapper"]="https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
    ["ComfyUI-VideoHelperSuite"]="https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
    
    # Nhóm Điều khiển & Nhận diện (IPAdapter, ControlNet)
    ["ComfyUI_IPAdapter_plus"]="https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"
    ["ComfyUI-ControlNet-Aux"]="https://github.com/Fannovel16/comfyui_controlnet_aux.git"
    ["ComfyUI-Advanced-ControlNet"]="https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git"
    
    # Nhóm Fallback (Dự phòng cho Animation)
    ["ComfyUI-AnimateDiff-Evolved"]="https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved.git"

    # Nhóm Hậu Kỳ: Chuyển cảnh, Hiệu ứng, Đổ chữ (NEW 🌟)
    ["ComfyUI-Impact-Pack"]="https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
    ["ComfyUI_essentials"]="https://github.com/cubiq/ComfyUI_essentials.git" # Các phép toán mask, resize siêu tốc
    ["ComfyUI-KJNodes"]="https://github.com/Kijai/ComfyUI-KJNodes.git" # Tạo mask động, transition, noise
    ["ComfyUI-Easy-Use"]="https://github.com/yolain/ComfyUI-Easy-Use.git" # Chèn Text, Font, Layout cực mạnh
    
    # Nhóm Upscale & Frame Interpolation (NEW 🌟)
    ["ComfyUI-Frame-Interpolation"]="https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git" # Tăng frame lên 60fps
    ["ComfyUI_UltimateSDUpscale"]="https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" # Upscale 4K chi tiết
)

for node in "${!NODES[@]}"; do
    if [ ! -d "$node" ]; then
        echo "⬇️ Đang clone $node..."
        git clone "${NODES[$node]}"
    else
        echo "✅ Node $node đã tồn tại."
    fi
done

# Cài đặt dependencies Python ngầm cho tất cả nodes
echo "🔧 Đang cài đặt thư viện Python (Quá trình này có thể mất vài phút)..."
for dir in */ ; do
    if [ -f "$dir/requirements.txt" ]; then
        pip install -r "$dir/requirements.txt" -q
    fi
done

# Bổ sung các thư viện hệ thống cần cho video và font chữ
apt-get update -y && apt-get install -y ffmpeg libsm6 libxext6 fonts-liberation

# ==============================================================================
# PHẦN 2: TẢI MODEL CỐT LÕI (WAN, FLUX, VAE, CLIP)
# ==============================================================================
cd "$COMFY_DIR"
echo "🧠 Đang tải Base Models..."

fast_download "https://huggingface.co/city96/Wan2.1-I2V-14B-720P-GGUF/resolve/main/wan2.1-i2v-14b-720p-Q8_0.gguf" "$COMFY_DIR/models/unet" "wan2.1-i2v-14b-720p-Q8_0.gguf"
fast_download "https://huggingface.co/Wan-Video/Wan2.1-I2V-14B-720P/resolve/main/wan_vae.safetensors" "$COMFY_DIR/models/vae" "wan_vae.safetensors"
fast_download "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" "$COMFY_DIR/models/clip" "t5xxl_fp8_e4m3fn.safetensors"
fast_download "https://huggingface.co/city96/FLUX.1-schnell-gguf/resolve/main/flux1-schnell-Q8_0.gguf" "$COMFY_DIR/models/unet" "flux1-schnell-Q8_0.gguf"

# ==============================================================================
# PHẦN 3: TẢI MODEL ĐIỀU KHIỂN & ANIMATION (IPADAPTER, CONTROLNET)
# ==============================================================================
echo "🎨 Đang tải ControlNet, IPAdapter & AnimateDiff Models..."

fast_download "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors" "$COMFY_DIR/models/clip_vision" "clip_vision_h.safetensors"
fast_download "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors" "$COMFY_DIR/models/ipadapter" "ip-adapter-plus_sdxl_vit-h.safetensors"
fast_download "https://huggingface.co/diffusers/controlnet-depth-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors" "$COMFY_DIR/models/controlnet" "controlnet_depth_sdxl.safetensors"
fast_download "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt" "$COMFY_DIR/models/ultralytics/bbox" "face_yolov8m.pt"

ANIMATEDIFF_DIR="$COMFY_DIR/custom_nodes/ComfyUI-AnimateDiff-Evolved/models"
fast_download "https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_mm.ckpt" "$ANIMATEDIFF_DIR" "v3_sd15_mm.ckpt"

# ==============================================================================
# PHẦN 4: TẢI MODEL HẬU KỲ (UPSCALER & FRAME INTERPOLATION) - NEW 🌟
# ==============================================================================
echo "✨ Đang tải Models Hậu Kỳ (4K Upscale & 60FPS Smooth)..."

# Model Upscaler huyền thoại: 4x-UltraSharp (Nét căng, giữ chi tiết sản phẩm cực tốt)
fast_download "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth" "$COMFY_DIR/models/upscale_models" "4x-UltraSharp.pth"

# Model Frame Interpolation (RIFE) - Giúp video Wan 2.1 mượt mà không bị sượng
VFI_DIR="$COMFY_DIR/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife"
fast_download "https://huggingface.co/styler00dollar/VSGAN-tensorrt-docker/resolve/main/models/rife47.pth" "$VFI_DIR" "rife47.pth"
# ==============================================================================
# PHẦN 5: CÀI ĐẶT FONT CHỮ THƯƠNG HIỆU & QUẢNG CÁO
# ==============================================================================
echo "🔤 Đang cài đặt phông chữ độc quyền cho Text Node..."

FONT_DIR="/usr/share/fonts/truetype/custom_ads_fonts"
mkdir -p "$FONT_DIR"

# Ví dụ tải các font từ kho lưu trữ của bạn (thay URL bằng link thực tế của bạn)
# Font mạnh mẽ cho Hook/Tiêu đề
fast_download "https://link-toi-r2-cua-ban.com/fonts/BebasNeue-Regular.ttf" "$FONT_DIR" "BebasNeue-Regular.ttf"
fast_download "https://link-toi-r2-cua-ban.com/fonts/Montserrat-Black.ttf" "$FONT_DIR" "Montserrat-Black.ttf"

# Font sang trọng, bay bổng
fast_download "https://link-toi-r2-cua-ban.com/fonts/PlayfairDisplay-Bold.ttf" "$FONT_DIR" "PlayfairDisplay-Bold.ttf"

# Cập nhật bộ nhớ đệm font của hệ điều hành để ComfyUI nhận diện ngay lập tức
fc-cache -f -v

echo "✅ Đã cài đặt xong phông chữ!"

echo "🎉 CHUẨN BỊ HOÀN TẤT! Hệ thống đã sở hữu sức mạnh của một Studio chuyên nghiệp."
