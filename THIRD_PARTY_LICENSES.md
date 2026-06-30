# Third-Party Licenses

The gemorna-nutshell pipeline integrates the following upstream tools. Their
licenses are reproduced (or summarised + linked) below in dependency order:
load-bearing tools first, then permissively-licensed Python dependencies.

The composite work — i.e. this repository plus any `.sif` / Docker artefact
built from `apptainer.def` — is governed by the **most restrictive of these
licenses** (GEMORNA's). See the top-level `LICENSE` for the inherited terms.

---

## 1. GEMORNA (RainaBio)

- **Upstream:** https://github.com/RainaBio/GEMORNA
- **Used by:** every mode (CDS / 5utr_gen / 3utr_gen / 5utr_pred / 3utr_pred /
  full_mrna). Source code, model checkpoints, and tokenizer vocabularies are
  bundled into the Apptainer image.
- **License (verbatim):**

> The Software is made publicly available by Licensor on Github for
> accessibility; however, it is licensed solely for non-commercial research
> purposes. By accessing, downloading, or using the Software, you ("Licensee")
> agree to the following terms:
>
> Licensor grants Licensee a non-exclusive, non-transferable, non-sublicensable,
> royalty-free license to use, reproduce, and modify the Software solely for
> non-commercial use and research. Any commercial use of the Software,
> including use in commercial research, product development, consulting, or
> internal business operations, is strictly prohibited without prior written
> permission from Licensor.
>
> Licensee may not distribute, sublicense, or otherwise make the Software or
> derivative works thereof available to third parties, except as necessary to
> publish academic research in accordance with standard academic practice.
>
> All copies and modifications of the Software must retain this License and
> appropriate attribution to Licensor. The Software is provided "as is"
> without warranty of any kind. All rights not expressly granted herein are
> reserved by Licensor.
>
> For any questions regarding this License or for use of the License for
> commercial or business purposes, please contact the corresponding author at
> caojicong@rainabio.com.

---

## 2. LinearFold (Huang Lab, Oregon State University)

- **Upstream:** https://github.com/LinearFold/LinearFold
- **Used by:** full_mrna mode (pair-ratio calculation for assembled mRNAs).
  Built from source inside the Apptainer image (`apptainer.def`).
- **Citation required:** Liang Huang, He Zhang, Dezhong Deng, Kai Zhao,
  Kaibo Liu, David Hendrix, and David Mathews (2019). *LinearFold:
  Linear-Time Approximate RNA Folding by 5'-to-3' Dynamic Programming and
  Beam Search.* Bioinformatics 35, Special Issue of ISMB 2019 Proceedings.
- **License (verbatim):**

> Disclaimer and Copyright
>
> The programs, library and source code of the LinearFold Package are free
> software. They are distributed in the hope that they will be useful but
> WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
> or FITNESS FOR A PARTICULAR PURPOSE.
>
> Permission is granted for research, educational, and commercial use and
> modification so long as 1) the package and any derived works are not
> redistributed for any fee, other than media costs, 2) proper credit is
> given to the authors. Please cite the following paper:
>
> Liang Huang, He Zhang, Dezhong Deng, Kai Zhao, Kaibo Liu, David Hendrix,
> and David Mathews (2019). LinearFold: Linear-Time Approximate RNA Folding
> by 5'-to-3' Dynamic Programming and Beam Search. Bioinformatics, Vol. 35,
> July 2019, Special Issue of ISMB 2019 Proceedings.
>
> corresponding author: Liang Huang <liang.huang.sh@gmail.com>
>
> If you want to include this software in a commercial product, please
> contact the corresponding author.

---

## 3. Snakemake

- **Upstream:** https://github.com/snakemake/snakemake
- **Used by:** workflow orchestration (every mode). Pipeline entry-point.
- **License:** MIT License.

> MIT License — Copyright (c) Johannes Köster <johannes.koester@uni-due.de>
>
> Permission is hereby granted, free of charge, to any person obtaining a
> copy of this software and associated documentation files (the "Software"),
> to deal in the Software without restriction, including without limitation
> the rights to use, copy, modify, merge, publish, distribute, sublicense,
> and/or sell copies of the Software, and to permit persons to whom the
> Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
> FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
> DEALINGS IN THE SOFTWARE.

---

## 4. micromamba / mamba

- **Upstream:** https://github.com/mamba-org/mamba
- **Used by:** Apptainer image base — installs the GEMORNA conda env from
  `environment.yaml`.
- **License:** BSD-3-Clause.

> Copyright (c) 2019, QuantStack and Mamba Contributors. All rights reserved.
>
> Redistribution and use in source and binary forms, with or without
> modification, are permitted provided that the following conditions are met:
>
> 1. Redistributions of source code must retain the above copyright notice,
>    this list of conditions and the following disclaimer.
> 2. Redistributions in binary form must reproduce the above copyright
>    notice, this list of conditions and the following disclaimer in the
>    documentation and/or other materials provided with the distribution.
> 3. Neither the name of the copyright holder nor the names of its
>    contributors may be used to endorse or promote products derived from
>    this software without specific prior written permission.
>
> THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
> AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
> IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
> ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
> LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
> CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
> SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
> INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
> CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
> ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
> POSSIBILITY OF SUCH DAMAGE.

---

## 5. Apptainer / Singularity-CE

- **Upstream:** https://github.com/apptainer/apptainer
- **Used by:** containerised execution (`SIF_PATH` set).
- **License:** BSD-3-Clause.

See the upstream `LICENSE.md` for the full text — substantially identical to
the BSD-3-Clause text reproduced under "micromamba" above. The Linux Foundation
holds the copyright; the project (formerly Singularity) was relicensed under
BSD-3-Clause in 2018.

---

## 6. Python scientific stack (transitive dependencies)

These are pulled in by GEMORNA's `environment.yaml` and Snakemake's deps. All
are permissively licensed and impose no additional constraints on the
composite work beyond attribution in the wheel/conda package metadata.

| Package         | License            | Upstream                                  |
|-----------------|--------------------|-------------------------------------------|
| PyTorch         | BSD-3-Clause       | https://github.com/pytorch/pytorch        |
| torchvision     | BSD-3-Clause       | https://github.com/pytorch/vision         |
| torchaudio      | BSD-2-Clause       | https://github.com/pytorch/audio          |
| torchtext       | BSD-3-Clause       | https://github.com/pytorch/text           |
| NumPy           | BSD-3-Clause       | https://github.com/numpy/numpy            |
| pandas          | BSD-3-Clause       | https://github.com/pandas-dev/pandas      |
| scikit-learn    | BSD-3-Clause       | https://github.com/scikit-learn/scikit-learn |
| Biopython       | Biopython License¹ | https://github.com/biopython/biopython    |
| tqdm            | MIT + MPL-2.0      | https://github.com/tqdm/tqdm              |
| PyYAML          | MIT                | https://github.com/yaml/pyyaml            |
| jsonschema      | MIT                | https://github.com/python-jsonschema/jsonschema |

¹ The Biopython License Agreement is a permissive BSD-style license; see
the upstream `LICENSE.rst` for the full text.

---

## Why the composite is non-commercial

Because GEMORNA (§1) prohibits commercial use without separate written
permission, **the whole pipeline inherits that restriction** regardless of how
permissive the other components are. If you replace GEMORNA with a
permissively-licensed alternative, the inherited restriction goes with it —
and the top-level `LICENSE` should be updated accordingly.
