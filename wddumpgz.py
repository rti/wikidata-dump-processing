import gzip
import time

PATH = "/home/rti/tmp/wikidata-20240514/wikidata-20240514.json.gz"
BATCH = 10000

def handle_batch(batch):
    print(len(batch))

def batch_lines(lines_func, count):
    batch = []
    for line in lines_func():
        batch.append(line)
        if(len(batch) == count):
            yield batch
            batch = []

def read_gz_in_lines(file_path, chunk_size=1024*1024):
    with gzip.open(file_path, "rt") as f:
        buffer = ""
        while True:
            data = f.read(chunk_size)
            if not data:
                if buffer:
                    yield buffer
                break
            buffer += str(data)
            while "\n" in buffer:
                line, buffer = buffer.split("\n", 1)
                yield line
        if buffer:
            yield buffer

if __name__ == "__main__":
    items_per_second_list = []

    start = time.time()
    for batch in batch_lines(lambda: read_gz_in_lines(PATH), BATCH):
        duration = time.time() - start
        start = time.time()
        handle_batch(batch)
        batchsize = len(batch)
        items_per_second = batchsize / duration
        items_per_second_list.append(items_per_second)

        avg = sum(items_per_second_list) / len(items_per_second_list)

        print(f"{duration=}")
        print(f"{items_per_second=:.1f}")
        print(f"{avg=:.1f}")
