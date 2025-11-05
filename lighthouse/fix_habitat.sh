pip uninstall -y tensorflow
pip install transformers==4.20
cp -r /dependencies/Grounded-Segment-Anything/ /home/junzhewu/scratch/
sed -i.bak '65s/\.type()/\.scalar_type()/g;135s/\.type()/\.scalar_type()/g' /home/junzhewu/scratch/Grounded-Segment-Anything/GroundingDINO/groundingdino/models/GroundingDINO/csrc/MsDeformAttn/ms_deform_attn_cuda.cu
cd /home/junzhewu/scratch/Grounded-Segment-Anything && python -m pip install --no-cache-dir --no-build-isolation -e GroundingDINO