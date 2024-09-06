from dask.distributed import Client
import time

def process(arg):
    # time.sleep(1)
    # return arg
    import torch
    has_cuda = torch.cuda.is_available()
    return f"{has_cuda=}"

def main():
    client = Client("dask-scheduler.rtti.de:8786")
    print(client.dashboard_link)

    futures = [client.submit(process, i) for i in range(10)]
    print("all tasks submitted")

    results = client.gather(futures)
    print("all tasks gathered")

    results = [future.result() for future in futures]
    print("results:", results)
    print("All tasks completed:", all(future.status == 'finished' for future in futures))

if __name__ == "__main__":
    main()
