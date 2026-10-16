
import time

start = time.perf_counter()

x = 0
for i in range(1, 20):
    x += i
print(x)

end = time.perf_counter()

print("Time taken:", end - start, "seconds")
