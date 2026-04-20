#!/bin/bash

# ==============================================================================
# HỆ THỐNG PROVISIONING SUNSIGN AI - CHIẾN THUẬT "CHẠY NHANH - LƯU BỀN"
# Tự động nhận diện: Lần đầu (Tải dữ liệu) vs Các lần sau (Chỉ liên kết)
# ==============================================================================

NET_DIR="/netspace/ComfyUI"
LOCAL_DIR="/workspace/ComfyUI"

echo "🚀 Bắt đầu cấu hình Video AI Engine..."

# --- BƯỚC 1: KHỞI TẠO CẤU TRÚC (Nếu Network Volume mới tinh) ---
mkdir -p "$NET_DIR/models/unet" "$NET_DIR/models/text_encoders" "$NET_DIR/models/loras"
mkdir -p "$NET_DIR/models/vae" "$NET_DIR/models/clip" "$NET_DIR/models/controlnet"
mkdir -p "$NET_DIR/models/ipadapter" "$NET_DIR/models/clip_vision" "$NET_DIR/models/sams"
mkdir -p "$NET_DIR/models/upscale_models" "$NET_DIR/models/insightface"
mkdir -p "$NET_DIR/custom_nodes"

# --- BƯỚC 2: HÀM LIÊN KẾT THÔNG MINH (Symlink Magic) ---
function smart_link() {
    local folder=$1
    local src="$LOCAL_DIR/$folder"
    local dst="$NET_DIR/$folder"

    echo "🔗 Đang xử lý liên kết cho: $folder"

    if [ -d "$src" ] && [ ! -L "$src" ]; then
        echo "   -> Phát hiện dữ liệu gốc trong Image, đang đồng bộ sang Network Volume..."
        cp -rn "$src"/. "$dst/" 2>/dev/null 
        rm -rf "$src" 
    fi

    ln -sfn "$dst" "$src"
    echo "   ✅ Đã thông tuyến: $src ---> $dst"
}

smart_link "models"
smart_link "custom_nodes"

# --- BƯỚC 3: TỰ ĐỘNG TẠO NODE TẢI ẢNH TỪ URL (Luôn nằm trên Netspace) ---
cat <<EOF > "$NET_DIR/custom_nodes/sunsign_image_from_url.py"
import requests, torch, io, numpy as np
from PIL import Image, ImageOps
class LoadImageFromURL:
    @classmethod
    def INPUT_TYPES(s): return {"required": {"url": ("STRING", {"default": ""})}}
    RETURN_TYPES, FUNCTION, CATEGORY = ("IMAGE", "MASK"), "load", "Sunsign AI"
    def load(self, url):
        res = requests.get(url, timeout=15)
        i = Image.open(io.BytesIO(res.content))
        i = ImageOps.exif_transpose(i)
        image = np.array(i.convert("RGB")).astype(np.float32) / 255.0
        mask = 1. - (np.array(i.getchannel('A')).astype(np.float32) / 255.0) if 'A' in i.getbands() else np.zeros((64,64), dtype=np.float32)
        return (torch.from_numpy(image)[None,], torch.from_numpy(mask))
NODE_CLASS_MAPPINGS = {"SunsignLoadImageURL": LoadImageFromURL}
NODE_DISPLAY_NAME_MAPPINGS = {"SunsignLoadImageURL": "Sunsign Load Image (URL)"}
EOF

# --- BƯỚC 4: HÀM TẢI MODEL THÔNG MINH (Idempotent) ---
function fast_download() {
    local url=$1
    local rel_path=$2
    local filename=$3
    local target="$NET_DIR/$rel_path/$filename"

    if [ ! -f "$target" ]; then
        echo "📥 Tải mới: $filename..."
        aria2c -x 16 -s 16 -k 1M -c "$url" -d "$NET_DIR/$rel_path" -o "$filename" || \
        wget -c "$url" -O "$target"
    else
        echo "✅ Đã có: $filename (Bỏ qua)"
    fi
}

# --- BƯỚC 5: CÀI ĐẶT HỆ SINH THÁI CUSTOM NODES ---
echo "📦 Đang cài đặt thư viện Custom Nodes vào Network Volume..."
cd "$NET_DIR/custom_nodes"

declare -A NODES=(
    ["ComfyUI-Manager"]="https://github.com/ltdrdata/ComfyUI-Manager.git"
    ["rgthree-comfy"]="https://github.com/rgthree/rgthree-comfy.git"
    ["ComfyUI-GGUF"]="https://github.com/city96/ComfyUI-GGUF.git"
    ["ComfyUI-WanVideoWrapper"]="https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
    ["ComfyUI-VideoHelperSuite"]="https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
    ["ComfyUI-Frame-Interpolation"]="https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git"
    ["ComfyUI_IPAdapter_plus"]="https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"
    ["ComfyUI-ControlNet-Aux"]="https://github.com/Fannovel16/comfyui_controlnet_aux.git"
    ["ComfyUI-Advanced-ControlNet"]="https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git"
    ["ComfyUI-segment-anything"]="https://github.com/storyicon/comfyui_segment_anything.git"
    ["ComfyUI-Impact-Pack"]="https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
    ["ComfyUI-LayerStyle"]="https://github.com/chflame163/ComfyUI-LayerStyle.git"
    ["ComfyUI_essentials"]="https://github.com/cubiq/ComfyUI_essentials.git"
    ["ComfyUI-KJNodes"]="https://github.com/Kijai/ComfyUI-KJNodes.git"
    ["ComfyUI-Easy-Use"]="https://github.com/yolain/ComfyUI-Easy-Use.git"
    ["ComfyUI_UltimateSDUpscale"]="https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
)

for node in "${!NODES[@]}"; do
    if [ ! -d "$node" ]; then
        echo "⬇️ Đang tải $node..."
        env GIT_TERMINAL_PROMPT=0 git clone "${NODES[$node]}"
    fi
done

# --- BƯỚC 6: TẢI TOÀN BỘ AI MODELS CỐT LÕI ---
echo "🧠 Đang đồng bộ Models..."

# 6.1 Wan 2.1 & Flux
fast_download "https://huggingface.co/city96/Wan2.1-I2V-14B-720P-GGUF/resolve/main/wan2.1-i2v-14b-720p-Q8_0.gguf" "models/unet" "wan2.1-i2v-14b-720p-Q8_0.gguf"
fast_download "https://huggingface.co/Wan-Video/Wan2.1-I2V-14B-720P/resolve/main/wan_vae.safetensors" "models/vae" "wan_vae.safetensors"
fast_download "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" "models/clip" "t5xxl_fp8_e4m3fn.safetensors"
fast_download "https://huggingface.co/city96/FLUX.1-schnell-gguf/resolve/main/flux1-schnell-Q8_0.gguf" "models/unet" "flux1-schnell-Q8_0.gguf"

# 6.2 LTX-2.3
fast_download "https://huggingface.co/Lightricks/LTX-2.3-fp8/resolve/main/ltx-2.3-22b-distilled-fp8.safetensors" "models/unet" "ltx-2.3-22b-distilled-fp8.safetensors"
fast_download "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors" "models/text_encoders" "gemma_3_12B_it_fp4_mixed.safetensors"
fast_download "https://huggingface.co/valiantcat/LTX-2.3-Transition-LORA/resolve/main/ltx2.3-transition.safetensors" "models/loras" "ltx2.3-transition.safetensors"

# 6.3 IPAdapter & Insightface
fast_download "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors" "models/clip_vision" "clip_vision_h.safetensors"
fast_download "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors" "models/ipadapter" "ip-adapter-plus_sdxl_vit-h.safetensors"
fast_download "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt" "models/ultralytics/bbox" "face_yolov8m.pt"
if [ ! -d "$NET_DIR/models/insightface/models/antelopev2" ]; then
    fast_download "https://github.com/deepinsight/insightface/releases/download/v0.7/antelopev2.zip" "models/insightface" "antelopev2.zip"
    unzip -q -o "$NET_DIR/models/insightface/antelopev2.zip" -d "$NET_DIR/models/insightface/models/antelopev2"
    rm "$NET_DIR/models/insightface/antelopev2.zip"
fi

# 6.4 SAM & ControlNet
fast_download "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" "models/sams" "sam_vit_b_01ec64.pth"
fast_download "https://huggingface.co/diffusers/controlnet-depth-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors" "models/controlnet" "controlnet_depth_sdxl.safetensors"
fast_download "https://huggingface.co/diffusers/controlnet-canny-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors" "models/controlnet" "controlnet_canny_sdxl.safetensors"
fast_download "https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors" "models/controlnet" "OpenPoseXL2.safetensors"

# 6.5 Hậu kỳ
fast_download "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth" "models/upscale_models" "4x-UltraSharp.pth"
fast_download "https://huggingface.co/styler00dollar/VSGAN-tensorrt-docker/resolve/main/models/rife47.pth" "custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife" "rife47.pth"

# --- BƯỚC 7: CÀI ĐẶT FONT CHỮ THƯƠNG HIỆU ---
echo "🔤 Cấu hình Font chữ thương hiệu..."
FONT_DIR="/usr/share/fonts/truetype/sunsign_fonts"
mkdir -p "$FONT_DIR"
if [ ! -d "/tmp/sunsignai_repo" ]; then
    git clone --depth 1 https://github.com/minhjax/sunsignai.git /tmp/sunsignai_repo
    cp -r /tmp/sunsignai_repo/fonts/* "$FONT_DIR/" 2>/dev/null
    fc-cache -f -v
    rm -rf /tmp/sunsignai_repo
fi

# --- BƯỚC 8: CÀI ĐẶT DEPENDENCIES ---
echo "🔧 Đang cài đặt thư viện hệ thống và Python..."
apt-get update -y && apt-get install -y aria2 wget unzip git ffmpeg libsm6 libxext6 fonts-liberation fontconfig
pip install -r "$LOCAL_DIR/requirements.txt" --quiet --root-user-action=ignore

for d in "$LOCAL_DIR/custom_nodes"/*/; do
    if [ -f "$d/requirements.txt" ]; then
        pip install -r "$d/requirements.txt" --quiet --root-user-action=ignore
    fi
done

echo "🎉 HỆ THỐNG SUNSIGN ĐÃ HOÀN TẤT VÀ SẴN SÀNG!"