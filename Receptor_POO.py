import serial
from datetime import datetime

class Receptor (object):
    def __init__(self, PORT: str, BAUD: int = 115200):
        self.PORT = PORT
        self.BAUD = BAUD


class SalvarArquivo (object):
    def __init__(self, qtd_sensores: int = 3):
        self.qtd_sensores = qtd_sensores
        self.nome_arquivo = f"HOMEFISIO_DADOS_{self.qtd_sensores}_SENSORES_"
        print(self.nome_arquivo)


def main():
    arquivo = SalvarArquivo()
if __name__ == "__main__":
    main()