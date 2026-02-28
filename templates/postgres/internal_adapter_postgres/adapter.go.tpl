package postgres

import (
	pgxPool "{{MODULE}}/pkg/postgres"
)

type Adapter struct {
	pool *pgxPool.Pool
}

func New(pgPool *pgxPool.Pool) *Adapter {
	return &Adapter{
		pool: pgPool,
	}
}
