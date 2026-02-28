package example_uc

import (
	"context"

	"go.uber.org/zap"
)

type Usecase struct {
	logger *zap.SugaredLogger
}

func New(log *zap.SugaredLogger) *Usecase {
	return &Usecase{
		logger: log,
	}
}

func (u *Usecase) Execute(ctx context.Context, input Input) (Output, error) {
	return Output{}, nil
}
