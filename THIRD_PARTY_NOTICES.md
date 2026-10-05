# Third-party software and models

Photo Views code and original generated demo artwork are covered by [LICENSE](LICENSE). That license does not replace upstream dependency/model terms. Dependencies and weights are installed separately, outside this repository; this repository does not redistribute them.

| Component | Used version/revision | Upstream license/source |
| --- | --- | --- |
| OpenCLIP software | 3.3.0 | [MIT](https://github.com/mlfoundations/open_clip/blob/main/LICENSE) |
| LAION CLIP-ViT-B-32-laion2B-s34B-b79K weights | `1a25a446712ba5ee05982a381eed697ef9b435cf` | [Model card, MIT listing and intended-use guidance](https://huggingface.co/laion/CLIP-ViT-B-32-laion2B-s34B-b79K/blob/1a25a446712ba5ee05982a381eed697ef9b435cf/README.md) |
| PyTorch / torchvision | 2.14.1 / 0.29.1 | [PyTorch BSD-style license and bundled notices](https://github.com/pytorch/pytorch/blob/main/LICENSE), [torchvision BSD license](https://github.com/pytorch/vision/blob/main/LICENSE) |
| OpenCV Python headless | 4.11.0.86 | [Python packaging MIT license](https://github.com/opencv/opencv-python/blob/4.x/LICENSE.txt), [bundled third-party notices](https://github.com/opencv/opencv-python/blob/4.x/LICENSE-3RD-PARTY.txt); OpenCV ≥4.5 uses Apache 2.0 |
| YuNet face detector | 2023mar, Zoo revision below | [MIT, Shiqi Yu](https://github.com/opencv/opencv_zoo/blob/47534e27c9851bb1128ccc0102f1145e27f23f98/models/face_detection_yunet/LICENSE) |
| SFace face descriptors | 2021dec, Zoo revision below | [Apache 2.0](https://github.com/opencv/opencv_zoo/blob/47534e27c9851bb1128ccc0102f1145e27f23f98/models/face_recognition_sface/LICENSE) |
| Pillow | 12.3.0 | [MIT-CMU](https://github.com/python-pillow/Pillow/blob/main/LICENSE) |
| NumPy | 2.5.3 | [BSD-3-Clause and bundled notices](https://github.com/numpy/numpy/blob/main/LICENSE.txt) |
| SQLite | System library | [Public domain](https://www.sqlite.org/copyright.html) |

Face models use OpenCV Zoo revision `47534e27c9851bb1128ccc0102f1145e27f23f98`. Setup verifies weight checksums and downloads both model-directory LICENSE files beside the models. The complete search dependency version list is [requirements.lock](spikes/m0/requirements.lock); each installed package retains its upstream notices. A future bundled binary must include all applicable dependency and weight licenses/notices, including transitive components.

## Model suitability

The CLIP model card lists deployed use, commercial or otherwise, as out of scope. Its MIT listing is separate from that intended-use guidance. This repository demonstrates a research/hackathon prototype; production suitability and broader evaluation remain unresolved. We have not trained these models or established general retrieval, tag or identity accuracy.

People groups are anonymous suggestions with merge/exclusion controls. Use images you are authorized to process. No inferred names, demographic or emotion labels are provided.

Historical project notes incorrectly described both face model-directory licenses as Apache 2.0. The pinned upstream licenses were checked during public-release preparation: YuNet is MIT; SFace is Apache 2.0.
