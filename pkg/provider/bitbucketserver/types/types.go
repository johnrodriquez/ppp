package types

import (
	bbv1 "github.com/gfleury/go-bitbucket-v1"
)

type EventActor struct {
	ID   int
	Name string
}

type PullRequestEvent struct {
	Actor      EventActor
	PulRequest bbv1.PullRequest `json:"pullRequest"`
}

type PushRequestEventChange struct {
	ToHash string `json:"toHash"`
	RefID  string `json:"refId"`
}

type PushRequestEvent struct {
	Actor      EventActor `json:"actor"`
	Repository bbv1.Repository
	Changes    []PushRequestEventChange
}
