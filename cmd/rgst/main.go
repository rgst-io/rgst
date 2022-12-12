// Copyright (C) 2022 Jared Allard <jared@rgst.io>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Package main bootstraps a Kubernetes cluster.
package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"text/template"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"
)

const (
	// ApplicationsDirectory is the directory where all application templates
	// are stored.
	ApplicationsDirectory = "manifests" + string(filepath.Separator) + "apps"
)

// GKE is a GKE Cluster.
type GKE struct {
	// Project is the GCP Project to use.
	Project string

	// Region is the GCP Region to use.
	Region string

	// Name is the name of the GKE Cluster.
	// Defaults to the name of the cluster.
	Name string
}

// RGST is a cluster in the RGST cloud.
type RGST struct{}

// Cluster is a Kubernetes Cluster
type Cluster struct {
	// Name is the name of the Kubernetes Cluster. This is used
	// for DNS entries and thus must be unique and DNS compatible.
	Name string

	// Endpoint is the Kubernetes Cluster endpoint
	Endpoint string

	// RGST is a RGST Cluster.
	RGST *RGST `yaml:"rgst,omitempty"`

	// GKE is a GKE Cluster.
	GKE *GKE `yaml:"gke,omitempty"`
}

// Clusters is the `clusters.yaml` file
type Clusters struct {
	// Domain is the root domain for applications to use for DNS entries.
	Domain string `yaml:"domain"`

	// ClusterDomain is the root domain for all cluster specific DNS entries
	// to use.
	ClusterDomain string `yaml:"cluster_domain"`

	// Cluster is a list of clusters.
	Clusters []Cluster `yaml:"clusters"`
}

// loadClusters loads the clusters.yaml file and returns a list of clusters.
func loadClusters() (*Clusters, error) {
	f, err := os.Open("clusters.yaml")
	if err != nil {
		return nil, err
	}
	defer f.Close()

	var clusters Clusters
	if err := yaml.NewDecoder(f).Decode(&clusters); err != nil {
		return nil, err
	}
	return &clusters, nil
}

// applyAppTemplates applies all templates in "manifests/apps" to the cluster.
func applyAppTemplates(cs *Clusters, c *Cluster) error {
	// for each all templates in "manifests/apps" render them and apply them via
	// kubectl
	templates, err := os.ReadDir(ApplicationsDirectory)
	if err != nil {
		return err
	}

	for _, template := range templates {
		if template.IsDir() {
			continue
		}

		log.Info().Str("template", template.Name()).Msg("Applying template")
		if err := applyAppTemplate(cs, c, filepath.Join(ApplicationsDirectory, template.Name())); err != nil {
			return err
		}
	}

	return nil
}

// applyAppTemplate applies a single template to the cluster.
func applyAppTemplate(cs *Clusters, c *Cluster, path string) error {
	contents, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	tpl, err := template.New(filepath.Base(path)).Parse(string(contents))
	if err != nil {
		return err
	}

	return tpl.Execute(os.Stdout, map[string]interface{}{
		"Cluster": *c,
		"Config": map[string]interface{}{
			"Domain":        cs.Domain,
			"ClusterDomain": cs.ClusterDomain,
		},
	})
}

// bootstrapRGST bootstraps a RGST Kubernetes cluster.
// Not implemented.
func bootstrapRGST(cs *Clusters, c *Cluster) error {
	return fmt.Errorf("not implemented")
}

func bootstrapGKE(cs *Clusters, c *Cluster) error {
	log.Info().Msg("Bootstrapping GKE cluster")

	if err := applyAppTemplates(cs, c); err != nil {
		return err
	}

	return nil
}

// bootstrap bootstraps a Kubernetes cluster.
func bootstrap(clusterName string) error {
	clusters, err := loadClusters()
	if err != nil {
		return err
	}
	var c *Cluster
	for i := range clusters.Clusters {
		if clusters.Clusters[i].Name == clusterName {
			c = &clusters.Clusters[i]
			break
		}
	}
	if c == nil {
		return fmt.Errorf("cluster %q not found", clusterName)
	}

	if c.RGST != nil {
		return bootstrapRGST(clusters, c)
	} else if c.GKE != nil {
		return bootstrapGKE(clusters, c)
	}

	return fmt.Errorf("cluster %q has no provider", clusterName)
}

func entrypoint(cmd *cobra.Command, args []string) {
	requiredTools := []string{
		"kubectl",
		"helm",
		"argocd",
		"gcloud",
		"jsonnet",
	}
	for _, tool := range requiredTools {
		if path, err := exec.LookPath(tool); err != nil || path == "" {
			log.Fatal().Str("tool", tool).Msg("required tool not found")
		}
	}

	// clusterName is the name of the Kubernetes cluster to bootstrap.
	// should exist in the current directory.
	//
	// Note: It is safe to index this without checking the length of args
	// as we have set the command to require exactly one argument.
	clusterName := args[0]

	if err := bootstrap(clusterName); err != nil {
		log.Fatal().Err(err).Msg("failed to bootstrap cluster")
	}
}

// main is the entry point for the program.
func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr})

	rootCmd := &cobra.Command{
		Use:   "rgst <cluster>",
		Short: "Bootstrap a Kubernetes Cluster",
		Args:  cobra.ExactArgs(1),
		Run:   entrypoint,
	}
	if err := rootCmd.ExecuteContext(ctx); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
