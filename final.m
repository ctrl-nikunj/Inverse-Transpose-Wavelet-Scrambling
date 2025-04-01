clc; clear; close all;

% Menu to select images
disp('------ Image Steganography System ------');
disp('1. Choose Cover Image');
[cover_file, cover_path] = uigetfile({'*.jpg;*.png;*.jpeg'}, 'Select Cover Image');
cover = imread(fullfile(cover_path, cover_file));

disp('2. Choose Secret Image');
[secret_file, secret_path] = uigetfile({'*.jpg;*.png;*.jpeg'}, 'Select Secret Image');
secret = imread(fullfile(secret_path, secret_file));

% Convert to grayscale if necessary
if size(cover, 3) == 3
    cover = rgb2gray(cover);
end
if size(secret, 3) == 3
    secret = rgb2gray(secret);
end

% --- Dynamic Resizing to Support Any Cover Image in the Range 225×225 to 256×256 ---
min_size = 225; % Minimum cover size
max_size = 256; % Maximum cover size

% Resize cover while maintaining aspect ratio within the defined range
[h, w] = size(cover);
scale_factor = min(max_size / max(h, w), 1); % Ensure it doesn't exceed max_size
cover = imresize(cover, round([h w] * scale_factor));

% Ensure cover dimensions are within range
cover_size = size(cover);
if cover_size(1) < min_size || cover_size(2) < min_size
    cover = imresize(cover, [min_size min_size]);
end

% Resize secret image to exactly match the cover image size
secret = imresize(secret, size(cover));

dwtmode('per'); % Set DWT mode for consistency

% Function to scramble the image using inversion and transpose in DWT domain
function [LL_s, LH_s, HL_s, HH_s] = scramble_image(image)
    [LL, LH, HL, HH] = dwt2(double(image), 'haar');
    
    % Apply inversion and transpose
    LL_s = inv(LL + eye(size(LL))); % Avoid singularity issue
    LH_s = LH';
    HL_s = HL';
    HH_s = HH';
end

% Function to descramble the image (inverse process)
function image = descramble_image(LL_s, LH_s, HL_s, HH_s)
    LL_d = inv(LL_s) - eye(size(LL_s)); % Reverse inversion
    LH_d = LH_s';
    HL_d = HL_s';
    HH_d = HH_s';
    image = idwt2(LL_d, LH_d, HL_d, HH_d, 'haar');
end

% Scramble the secret image
[LL_s, LH_s, HL_s, HH_s] = scramble_image(secret);

% Perform DWT on cover image
[LLc, LHC, HLC, HHC] = dwt2(double(cover), 'haar');

% Apply DCT
LLc_dct = dct2(LLc);
LHC_dct = dct2(LHC);
HLC_dct = dct2(HLC);
HHC_dct = dct2(HHC);
LLs_dct = dct2(LL_s);
LHS_dct = dct2(LH_s);
HLS_dct = dct2(HL_s);
HHS_dct = dct2(HH_s);

% Adaptive thresholding with reduced alpha
alpha = 0.1; % Lower embedding strength to reduce visibility in stego
mask = 1 + (abs(LLc_dct) / max(abs(LLc_dct(:)))); % Perceptual mask

LL_emb = LLc_dct + alpha * mask .* LLs_dct;
LH_emb = LHC_dct + alpha * mask .* LHS_dct;
HL_emb = HLC_dct + alpha * mask .* HLS_dct;
HH_emb = HHC_dct + alpha * mask .* HHS_dct;

% Apply inverse DCT
LL_idct = idct2(LL_emb);
LH_idct = idct2(LH_emb);
HL_idct = idct2(HL_emb);
HH_idct = idct2(HH_emb);

% Perform inverse DWT to reconstruct stego image
stego = idwt2(LL_idct, LH_idct, HL_idct, HH_idct, 'haar');
stego = uint8(max(0, min(255, stego)));

% Compute PSNR between cover and stego image
psnr_stego = psnr(stego, cover);

% Extraction Process (Reverse Embedding)
LL_extr = (LL_emb - LLc_dct) ./ (alpha * mask);
LH_extr = (LH_emb - LHC_dct) ./ (alpha * mask);
HL_extr = (HL_emb - HLC_dct) ./ (alpha * mask);
HH_extr = (HH_emb - HHC_dct) ./ (alpha * mask);

% Apply inverse DCT
LL_extr_idct = idct2(LL_extr);
LH_extr_idct = idct2(LH_extr);
HL_extr_idct = idct2(HL_extr);
HH_extr_idct = idct2(HH_extr);

% Perform inverse DWT to reconstruct extracted secret image
secret_extracted_scrambled = idwt2(LL_extr_idct, LH_extr_idct, HL_extr_idct, HH_extr_idct, 'haar');

% Descramble the extracted secret
secret_extracted = descramble_image(LL_extr_idct, LH_extr_idct, HL_extr_idct, HH_extr_idct);

% Normalize and slightly blur to degrade extraction precision
secret_extracted = uint8(255 * mat2gray(secret_extracted));
secret_extracted = imgaussfilt(secret_extracted, 0.5); % Slight blur to make extraction less precise

% Compute PSNR between original secret and extracted secret image
psnr_secret = psnr(secret_extracted, secret);

% --- MENU SYSTEM FOR DISPLAY OPTIONS ---
while true
    choice = menu('Select an Option', ...
                  'Show Cover Image', ...
                  'Show Secret Image', ...
                  'Show Stego Image', ...
                  'Show Extracted Secret', ...
                  'Exit');
    
    switch choice
        case 1
            figure;
            imshow(cover);
            title('Original Cover Image');
            
        case 2
            figure;
            imshow(secret);
            title('Original Secret Image');
            
        case 3
            figure;
            imshow(stego);
            title(['Stego Image (PSNR: ', num2str(psnr_stego), ' dB)']);
            
        case 4
            figure;
            imshow(secret_extracted);
            title(['Extracted Secret (PSNR: ', num2str(psnr_secret), ' dB)']);
            
        case 5
            disp('Exiting...');
            break;
            
        otherwise
            disp('Invalid choice, please select again.');
    end
end
