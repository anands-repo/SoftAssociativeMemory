# SoftAssociativeMemory

In this repository is a memory model that is inspired by the Sparse Distributed Memory (SDM) (P. Kanerva, 1988). I tried to code the SDM, and the simulation of a small number of accesses took a very long time. Hence, I wanted to build something a bit more light-weight, at the expense of losing some of the features of the SDM.

The basic idea behind the model is that (this was originally proposed by Kanerva) when information is encoded using a very large dimensionality vector (e.g., instead of using the name "Mary", use a 10,000 bit representation associated with "Mary"), the subspace of valid encodings will be sparse within the space of all such vectors. This means, noisy representations of a valid vector, or representations of variations of the same idea that is represented by a valid vector will be confined to balls around the vector that are small, and which do not intersect with balls associated with other vectors. Under these assumptions, it is possible to correct for errors in oncoming data by clustering the incoming data.

The memory model here implements an online clustering of the data under such assumptions using Verilog code that I believe is synthesizable (I haven't tried to synthesize it). In the experiment, a transmitter is setup to send Hamming coded information, but a channel corrupts the information before arriving at a receiver. The receiver has the Soft Associative Memory at its disposal. The Soft Associative Memroy is able to determine the original symbols being transmitted even without receiving a single symbol that has been unmodified by noise.

The experiment written here is small, but I think it would be pretty interesting to apply this to something like MNIST digit characterization.
