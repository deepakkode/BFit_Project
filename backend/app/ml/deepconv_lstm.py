from torch import Tensor, nn


class DeepConvLSTM(nn.Module):
    def __init__(
        self,
        num_classes: int = 4,
        input_channels: int = 3,
        convolution_channels: int = 64,
        hidden_size: int = 128,
        recurrent_layers: int = 2,
        dropout: float = 0.5,
    ) -> None:
        super().__init__()
        convolutions: list[nn.Module] = []
        channels = input_channels
        for _ in range(4):
            convolutions.extend([
                nn.Conv1d(channels, convolution_channels, kernel_size=5, padding=2),
                nn.BatchNorm1d(convolution_channels),
                nn.ReLU(),
            ])
            channels = convolution_channels
        self.convolutions = nn.Sequential(*convolutions)
        self.recurrent = nn.LSTM(
            input_size=convolution_channels,
            hidden_size=hidden_size,
            num_layers=recurrent_layers,
            batch_first=True,
            dropout=dropout if recurrent_layers > 1 else 0.0,
        )
        self.dropout = nn.Dropout(dropout)
        self.classifier = nn.Linear(hidden_size, num_classes)

    def forward(self, samples: Tensor) -> Tensor:
        if samples.ndim != 3 or samples.shape[-1] != 3:
            raise ValueError("Expected sensor windows shaped (batch, time, 3)")
        encoded = self.convolutions(samples.transpose(1, 2)).transpose(1, 2)
        recurrent, _ = self.recurrent(encoded)
        return self.classifier(self.dropout(recurrent[:, -1, :]))