# Security Policy

This document describes the security policy for this repository, including how to report vulnerabilities and what a security researcher can expect after submitting a report.

This project is part of a **Bachelor's Thesis (TFG - Trabajo de Fin de Grado)** for the **Degree in Computer Engineering at the Universidade da Coruña** and is distributed under the **MIT License**.

<br>

## Supported Versions

The project is under active development.

| Version / Branch   | Security Support                                           |
| ------------------ | ---------------------------------------------------------- |
| `main`             | Yes — always contains the most recent version of the project |
| Legacy versions    | Support is not guaranteed                                  |

Security fixes will be applied to the **main** branch.

## Scope of the Security Policy

This policy primarily applies to the following project components:

* Mobile application developed in **Flutter**
* Backend based on **Supabase**
* Integration with **IoT devices**
* Communication with devices via **HTTP, Bluetooth, and MQTT**

The following are out of scope:

* Vulnerabilities in **external libraries**
* Security issues in **third-party dependencies**
* Vulnerabilities inherent to external services like **Supabase**
* Issues arising from the operating system or the user's device

In these cases, it is recommended to report the issue directly to the maintainers of those tools.

## How to Report a Vulnerability

If you detect a potential security vulnerability, **do not open a public issue**.

Instead, you can:

1. Use the **GitHub Security Advisories** system if available.
2. Contact the project author directly via GitHub.

To facilitate the analysis, please try to include the following information:

* Clear description of the vulnerability
* Potential impact
* Affected components
* Steps to reproduce the problem
* Environment where the flaw was detected (device, operating system, etc.)

Providing a functional exploit is not necessary; a clear explanation is usually sufficient.

## Process After a Report

After receiving a security report, the following approximate process will be followed:

| Step                     | Estimated Time                |
| ------------------------ | ----------------------------- |
| Report acknowledgment    | 72 hours                      |
| Initial evaluation       | 7 days                        |
| Solution development     | Depending on complexity        |

As this is an **individually developed academic project**, response times may vary based on the author's availability.

## Responsible Disclosure

Following a **responsible vulnerability disclosure** model is recommended.

This means that:

* The researcher communicates the vulnerability privately.
* Reasonable time is given to develop a solution.
* Once the issue is fixed, the information can be made public.

This process helps protect the users of the software.

## Recognition

We appreciate individuals who report vulnerabilities responsibly.

Once a vulnerability is confirmed, the researcher may be recognized in the project documentation, unless they prefer to remain anonymous.

## Academic Context

This project has been developed as a **Bachelor's Thesis (TFG)** by **Iago Becerra López** for the:

**Degree in Computer Engineering – Major in Information Technologies - Universidade da Coruña**

---

Last review: March 2026
