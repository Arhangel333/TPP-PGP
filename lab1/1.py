n = 5000

with open("input.txt", "w") as f:
    f.write(str(n))
    f.write('\n')
    for i in range(2):
        for i in range(0, n):
            f.write('3.0 ')
            f.write('5.0 ')
            f.write('7.0 ')
        f.write('\n')
