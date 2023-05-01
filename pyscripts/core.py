import png
import base64

def get_chara_metadata(file_name):
    with open(file_name, 'rb') as f:
        png_reader = png.Reader(file=f)
        chunk_iterator = png_reader.chunks()

        metadata = {}
        for chunk_type, chunk_data in chunk_iterator:
            if chunk_type.decode() == 'tEXt':
                keyword, text = chunk_data.split(b'\0', 1)
                metadata[keyword.decode()] = text.decode()

        if 'chara' not in metadata:
            return ""

        chara_base64 = metadata['chara']
        chara_bytes = base64.b64decode(chara_base64)
        chara_str = chara_bytes.decode('utf-8')

        return chara_str